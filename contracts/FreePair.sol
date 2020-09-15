// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "IFreePair.sol";
import "SafeMath.sol";
import "IFreeFactory.sol";
import "IFreeERC20.sol";

contract FreePair is IFreePair {

    using SafeMath for uint256;

    string public sideChainName;
    IFreeFactory public iFreeFactory;
    IFreeERC20 public token;
    string[] public depositAddr;
    uint256 public depositNewRequestCount;

    bool public migrated;

    // todo 总质押量！！

    // 地址映射。
    struct SenderInfo {
        string senderOnSideChain;
        address sender;
    }
    mapping (bytes32 => SenderInfo) public senderInfoMap;

    struct PushAddrProposalInfo {
        string[] depositAddrs;
        uint8 approve;
        bool success;
    }
    PushAddrProposalInfo[] public pushAddrProposal;
    mapping (uint256 => mapping (address => bool)) private pushAddrProposalApprove;

    struct RetMintProposalInfo {
        string senderOnSideChain;
        uint256 amountOnSideChain;
        string txOnSideChain;
        address sender;
        uint256 amount;
        uint8 approve;
        bool success;
    }
    // 充值的时候，需要notary都签名了，才能mint，充值直接就是终态
    // 充值，用户也是发到这个合约！！
    // ERC20 mint 由这个合约控制
    struct MintProposalInfo {
        string senderOnSideChain;
        uint256 amountOnSideChain;
        string txOnSideChain;
        uint256 amount;
        uint8 approve;
        bool success;
    }

    MintProposalInfo[] public mintProposal;
    mapping (bytes32 => uint256) txOnSideChainIndex;
    mapping (uint256 => mapping (address => bool)) private mintProposalApprove;

    // 提现的时候，用户可以随便指定接收地址，burn之后，就产生了一条记录，
    // 提现，用户请求也是发到这个合约！！
    // 需要notary都签名了，提现才能确认成功
    // ERC20 burn 由这个合约控制 ？不行？？ 要么就回调
    struct BurnProposalInfo {
        address sender;
        uint256 amount;
        string recipientOnSideChain;
        uint256 amountOnSideChain;
        string txOnSideChain;
        uint8 approve;
        bool success;
    }
    BurnProposalInfo[] public burnProposal;
    mapping (uint256 => mapping (address => bool)) private burnProposalApprove;

    uint256 public migrateProposalApproveCount;
    mapping (address => bool) private migrateProposalApprove;

    constructor (string memory _sideChainName, address _token) public {
        iFreeFactory = IFreeFactory(msg.sender);
        sideChainName = _sideChainName;
        token = IFreeERC20(_token);
        mintProposal.push(MintProposalInfo("", 0, "", 0, 0, true));
    }

    function pushAddr(uint256 pushAddrProposalId, string[] memory addrs) public virtual override returns (bool) {
        require(iFreeFactory.notaryMap(msg.sender), "pushAddr can only be called by notary");
        if (pushAddrProposalId >= pushAddrProposal.length) {
            // new pushAddr proposal
            pushAddrProposal.push(PushAddrProposalInfo(addrs, 1, false));
            pushAddrProposalApprove[pushAddrProposal.length - 1][msg.sender] = true;
            // todo log list index
        } else {
            if (pushAddrProposalApprove[pushAddrProposalId][msg.sender] == false) {
                pushAddrProposal[pushAddrProposalId].approve += 1; // needn't SafeMath
                pushAddrProposalApprove[pushAddrProposalId][msg.sender] = true;
            }
        }

        if (pushAddrProposal[pushAddrProposalId].approve >= iFreeFactory.notaryCount() * 2 / 3 && pushAddrProposal[pushAddrProposalId].success == false) { // needn't SafeMath
            addrs = pushAddrProposal[pushAddrProposalId].depositAddrs;
            for (uint256 i = 0; i < addrs.length; i++) {
                depositAddr.push(addrs[i]);
            }
            pushAddrProposal[pushAddrProposalId].success = true;
            // todo log
            return true;
        } else {
            return false;
        }
    }

    function depositRequest(string memory senderOnSideChain) public virtual override returns (bool) {
        require(msg.sender != address(0), "sender can't be zero address");
        require(migrated == false, "this pair has migrated to pair v2, please use pair v2");
        bytes32 addrHash = keccak256(bytes(senderOnSideChain)); // todo test
        if (senderInfoMap[addrHash].sender == address(0)) {
            senderInfoMap[addrHash] = SenderInfo(senderOnSideChain, msg.sender);
            depositNewRequestCount += 1;
        } else {
            require(senderInfoMap[addrHash].sender == msg.sender, "the senderOnSideChain has been used by others");
        }
        uint256 index = depositNewRequestCount / 50000;
        if (index >= depositAddr.length) {
            index = depositAddr.length - 1;
        }
        emit DepositAddr(depositAddr[index]);
        return true;
    }

    // 每个代币的小数点的统计！！
    function depositConfirm(string memory txOnSideChain, string memory senderOnSideChain, uint256 amountOnSideChain, uint256 amount) public virtual override returns (bool) {
        require(iFreeFactory.notaryMap(msg.sender), "depositConfirm can only be called by notary");
        require(migrated == false, "this pair has migrated to pair v2, please use pair v2");
        address sender;
        uint256 mintProposalId = txOnSideChainIndex[keccak256(bytes(txOnSideChain))];
        if (mintProposalId == 0) {
            // new mint proposal
            sender = senderInfoMap[keccak256(bytes(senderOnSideChain))].sender;
            require(sender != address(0), "the senderOnSideChain has not sent depositRequest");
            mintProposal.push(MintProposalInfo(senderOnSideChain, amountOnSideChain, txOnSideChain, amount, 1, false));
            mintProposalId = mintProposal.length - 1;
            mintProposalApprove[mintProposalId][msg.sender] = true;
            txOnSideChainIndex[keccak256(bytes(txOnSideChain))] = mintProposalId;
            // todo log list index
        } else {
            // existed mint proposal
            senderOnSideChain = mintProposal[mintProposalId].senderOnSideChain;
            sender = senderInfoMap[keccak256(bytes(senderOnSideChain))].sender;
            require(sender != address(0), "the senderOnSideChain has not sent depositRequest");
            if (mintProposalApprove[mintProposalId][msg.sender] == false) {
                mintProposal[mintProposalId].approve += 1; // needn't SafeMath
                mintProposalApprove[mintProposalId][msg.sender] = true;
            }
        }

        if (mintProposal[mintProposalId].approve >= iFreeFactory.notaryCount() * 2 / 3 && mintProposal[mintProposalId].success == false) { // needn't SafeMath
            token.mint(sender, mintProposal[mintProposalId].amount); // fixme: internal error will revert?
            mintProposal[mintProposalId].success = true;
            // todo log
            return true;
        } else {
            return false;
        }
    }

    // 注意小数点转换！！
    function withdrawRequest(address sender, string memory recipientOnSideChain, uint256 amount) public virtual override returns (bool) {
        require(msg.sender == address(token), "sender must be the token");
        burnProposal.push(BurnProposalInfo(sender, amount, recipientOnSideChain, 0, "", 0, false));
        // todo log list index
        return true;
    }

    // 每个代币的小数点的统计！！
    function withdrawConfirm(uint256 burnProposalId, uint256 amountOnSideChain, string memory txOnSideChain) public virtual override returns (bool) {
        require(iFreeFactory.notaryMap(msg.sender), "withdrawConfirm can only be called by notary");
        require(burnProposalId < burnProposal.length, "burnProposalId exceeds the index range of burnProposal");
        // maybe one notary write wrong data, later multi-sign off-chain
        // use temp BurnProposalInfo will save gas ?
        if (burnProposal[burnProposalId].approve == 0) {
            burnProposal[burnProposalId].approve = 1;
            burnProposal[burnProposalId].amountOnSideChain = amountOnSideChain;
            burnProposal[burnProposalId].txOnSideChain = txOnSideChain;
            burnProposalApprove[burnProposalId][msg.sender] = true;
        } else {
            if (burnProposalApprove[burnProposalId][msg.sender] == false) {
                burnProposal[burnProposalId].approve += 1; // needn't SafeMath
                burnProposalApprove[burnProposalId][msg.sender] = true;
            }
        }

        if (burnProposal[burnProposalId].approve >= iFreeFactory.notaryCount() * 2 / 3 && burnProposal[burnProposalId].success == false) { // needn't SafeMath
            burnProposal[burnProposalId].success = true;
            // todo log
            return true;
        } else {
            return false;
        }
    }

    function migratePair(address newPair) public override returns (bool) {
        // for migration to v2 later
        require(iFreeFactory.notaryMap(msg.sender), "migratePair can only be called by notary");
        if (migrateProposalApprove[msg.sender] == false) {
            migrateProposalApproveCount += 1;
        }
        if (migrateProposalApproveCount >= iFreeFactory.notaryCount() * 2 / 3) {
            token.migratePair(newPair);
            migrated = true;
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

    function depositAddrCount() public view returns (uint256) {
        return depositAddr.length;
    }

    function senderOnSideChainToBase(string memory senderOnSideChain) public view returns (address) {
        return senderInfoMap[keccak256(bytes(senderOnSideChain))].sender;
    }

    function getMintList(uint256 fromInclusive, uint256 toExclusive) public view returns (RetMintProposalInfo[] memory, uint256) {
        require(fromInclusive > 0, "fromInclusive should be greater than 0");
        if (toExclusive > mintProposal.length) {
            toExclusive = mintProposal.length;
        }
        uint256 size = toExclusive - fromInclusive;
        RetMintProposalInfo[] memory ret = new RetMintProposalInfo[](size);
        uint256 i = 0;
        for (uint256 j = fromInclusive; j < toExclusive; j++) {
            MintProposalInfo storage mintInfo = mintProposal[j];
            address sender = senderInfoMap[keccak256(bytes(mintInfo.senderOnSideChain))].sender;
            ret[i++] = RetMintProposalInfo(mintInfo.senderOnSideChain, mintInfo.amountOnSideChain,
                mintInfo.txOnSideChain, sender, mintInfo.amount, mintInfo.approve, mintInfo.success);
        }
        return (ret, mintProposal.length); // todo
    }

    function getBurnList(uint256 fromInclusive, uint256 toExclusive) public view returns (BurnProposalInfo[] memory, uint256) {
        if (toExclusive > burnProposal.length) {
            toExclusive = burnProposal.length;
        }
        uint256 size = toExclusive - fromInclusive;
        BurnProposalInfo[] memory ret = new BurnProposalInfo[](size);
        uint256 i = 0;
        for (uint256 j = fromInclusive; j < toExclusive; j++) {
            ret[i++] = burnProposal[j];
        }
        return (ret, burnProposal.length);
    }

    function mintCount() public view returns (uint256) {
        return mintProposal.length;
    }

    function burnCount() public view returns (uint256) {
        return burnProposal.length;
    }

    function getMintStatus(uint256 mintProposalId) public view returns (bool) {
        return mintProposal[mintProposalId].success;
    }

    function getBurnStatus(uint256 burnProposalId) public view returns (bool) {
        return burnProposal[burnProposalId].success;
    }

    function getBurnInfo(uint256 burnProposalId) public view returns(address, uint256, string memory, uint256, string memory, uint8, bool) {
        BurnProposalInfo storage info = burnProposal[burnProposalId];
        return (info.sender, info.amount, info.recipientOnSideChain, info.amountOnSideChain, info.txOnSideChain,
        info.approve, info.success);
    }
}