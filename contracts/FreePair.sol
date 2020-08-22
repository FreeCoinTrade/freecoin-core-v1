// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "FreeFactory.sol"; // 循环引用吗？

contract FreePair {

    // deposit
    // withdraw
    // 停止FreeCoinPair的充值，只能提现，迁移到 V2
    // 上面3个的更换，都需要5个签名者同意
    // 更换FreeERC20的minter，开始是本合约

    using SafeMath for uint256;

    FreeFactory public freeFactory;
    string public sideChainName;
    FreeERC20 public token;
    address[] public depositAddr;
    uint256 public depositAddrIndex;

    // todo 总质押量！！

    // 地址映射。
    struct SenderInfo {
        string senderOnSideChain;
        address sender;
    }
    mapping (bytes32 => SenderInfo) public senderInfoMap;
    
    // 充值的时候，需要notary都签名了，才能mint，充值直接就是终态
    // 充值，用户也是发到这个合约！！
    // ERC20 mint 由这个合约控制
    struct MintProposalInfo {
        address sender;
        // string senderOnSideChain;
        uint8 approve;
        bool success;
        uint256 amount;
        string txOnSideChain;
    }
    MintProposalInfo[] public mintProposal;
    mapping (uint256 => mapping (address => bool)) private mintProposalApprove;
    
    // 提现的时候，用户可以随便指定接收地址，burn之后，就产生了一条记录，
    // 提现，用户请求也是发到这个合约！！
    // 需要notary都签名了，提现才能确认成功
    // ERC20 burn 由这个合约控制 ？不行？？ 要么就回调
    struct BurnProposalInfo {
        address sender;
        string recipientOnSideChain;
        uint8 approve;
        bool success;
        uint256 amount;
        string txOnSideChain;
    }
    BurnProposalInfo[] public burnProposal;
    uint256 public burnProposalCount;
    mapping (uint256 => mapping (address => bool)) private burnProposalApprove;
    
    uint256 public migrateProposalCount;
    mapping (address => bool) private migrateProposalApprove;

    constructor (string memory _sideChainName, address _token) public {
        freeFactory = FreeFactory(msg.sender);
        sideChainName = _sideChainName;
        token = FreeERC20(_token);
    }

    function depositRequest(string senderOnSideChain) public virtual returns (address) {
        require(msg.sender != address(0), "sender can't be zero address");
        bytes32 addrHash = keccak256(senderOnSideChain);
        if (senderInfoMap[addrHash].sender == address(0)) {
            senderInfoMap[addrHash] = SenderInfo(senderOnSideChain, msg.sender);
        } else {
            require(senderInfoMap[addrHash].sender == msg.sender, "the senderOnSideChain has been used by others");
        }
        depositAddrIndex += 1;
        return depositAddr[depositAddrIndex / 50000]; // todo test to add when init and fuction
    }
    
    // 每个代币的小数点的统计！！
    function depositConfirm(uint256 mintProposalId, string senderOnSideChain, uint256 amount, string txOnSideChain) public virtual returns (bool) {
        require(freeFactory.notaryMap(msg.sender), "depositConfirm can only be called by notary");
        address sender = senderInfoMap[keccak256(senderOnSideChain)].sender;
        require(sender != address(0), "the senderOnSideChain has not sent depositRequest");
        if (mintProposalId >= mintProposal.length) {
            // new mint proposal
            mintProposal.push(MintProposalInfo(sender, 1, false, amount, txOnSideChain));
            mintProposalApprove[mintProposal.length - 1][msg.sender] = true;
            // todo log list index
        } else {
            if (mintProposalApprove[mintProposalId][msg.sender] == false) {
                mintProposal[mintProposalId].approve += 1; // needn't SafeMath
                mintProposalApprove[mintProposalId][msg.sender] = true;    
            }
        }
        
        if (mintProposal[mintProposalId].approve >= freeFactory.notaryCount() * 2 / 3 && mintProposal[mintProposalId].success == false) { // needn't SafeMath
            token.mint(mintProposal[mintProposalId].sender, mintProposal[mintProposalId].amount); // fixme: will revert?
            mintProposal[mintProposalId].success = true;
            // todo log
            return true;
        } else {
            return false;
        }
    }
    
    // 注意小数点转换！！
    function withdrawRequest(address sender, string memory recipientOnSideChain, uint256 amount) public virtual returns (bool) {
        require(msg.sender == token, "sender must be the token");
        burnProposal.push(BurnProposalInfo(sender, recipientOnSideChain, 0, false, amount, ""));
        burnProposalCount += 1;
        // todo log list index
        return true;
    }
    
    // 每个代币的小数点的统计！！
    function withdrawConfirm(uint256 burnProposalId, string txOnSideChain) public virtual returns (bool) {
        require(freeFactory.notaryMap(msg.sender), "withdrawConfirm can only be called by notary");
        require(burnProposalId < burnProposal.length, "burnProposalId exceeds the index range of burnProposal");
        if (burnProposal[burnProposalId].approve == 0) {
            burnProposal[burnProposalId].approve = 1;
            burnProposal[burnProposalId].txOnSideChain = txOnSideChain;
            burnProposalApprove[burnProposalId][msg.sender] = true;
        } else {
            if (burnProposalApprove[burnProposalId][msg.sender] == false) {
                burnProposal[burnProposalId].approve += 1; // needn't SafeMath
                burnProposalApprove[burnProposalId][msg.sender] = true;    
            }
        }
        
        if (burnProposal[burnProposalId].approve >= freeFactory.notaryCount() * 2 / 3 && burnProposal[burnProposalId].success == false) { // needn't SafeMath
            burnProposal[burnProposalId].success = true;
            // todo log
            return true;
        } else {
            return false;
        }
    }

    function migratePair(address newPair) public returns (bool) {
        // for migration to v2 later
        require(freeFactory.notaryMap(msg.sender), "migratePair can only be called by notary");
        if (migrateProposalApprove[msg.sender] == false) {
            migrateProposalCount += 1;
        }
        if (migrateProposalCount >= freeFactory.notaryCount() * 2 / 3) {
            token.migratePair(newPair);
            return true;
        }
        return false;
    }

    function mintProposalCount() public view returns (uint256) {
        return mintProposal.length;
    }

    function burnProposalCount() public view returns (uint256) {
        return burnProposal.length;
    }
}
