// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IFreeERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event MigratePair(address oldPair, address newPair);
    
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function burn(uint256 amount, string memory recipientOnSideChain) external returns (bool);
    function burnFrom(address account, uint256 amount, string memory recipientOnSideChain) external;
    function mint(address account, uint256 amount) external returns (bool);
    function migratePair(address newPair) external returns (bool);
}