// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "IFreeERC20.sol";
import "SafeMath.sol";
import "FreePair.sol"; // 循环调用了吗？

// 1. token，此时肯定没有pair，pair临时为msg.sender
// 2. factory，里面创建pair
// 3. 在token中设置真正的pair

contract FreeERC20 is IFreeERC20 {
    
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    FreePair public pair;

    // 每个代币的小数点不一样，好好设计一下
    constructor (string memory name, string memory symbol, uint8 decimals) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
        pair = FreePair(msg.sender); // temp
    }
    
    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }
    
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }
    
    function burn(uint256 amount, string recipientOnSideChain) public virtual returns (bool) {
        // for redeem
        _burn(msg.sender, amount, recipientOnSideChain);
        return true;
    }
    
    function burnFrom(address account, uint256 amount, string recipientOnSideChain) public virtual {
        // for migration to v2 later
        uint256 decreasedAllowance = _allowances[account][msg.sender].sub(amount, "ERC20: burn amount exceeds allowance");
        _approve(account, msg.sender, decreasedAllowance);
        _burn(account, amount, recipientOnSideChain);
    }
    
    function mint(address account, uint256 amount) public virtual returns (bool) {
        require(msg.sender == pair, "ERC20: mint only can be called by pair");
        _mint(account, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }
    
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount, string memory recipientOnSideChain) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        pair.withdrawRequest(account, recipientOnSideChain, amount);
        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function migratePair(address newPair) public returns (bool) {
        // 1. for migration to v1 after create
        // 2. for migration to v2 later
        require(msg.sender == pair, "ERC20: migratePair only can be called by pair"); // todo test
        pair = FreePair(newPair);
    }
}