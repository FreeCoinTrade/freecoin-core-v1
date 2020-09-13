// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface IFreePair {

    event DepositAddr(string addr);
    // todo event

    function pushAddr(uint256 pushAddrProposalId, string[] memory addrs) external returns (bool);
    function depositRequest(string memory senderOnSideChain) external returns (bool);
    function depositConfirm(uint256 mintProposalId, string memory senderOnSideChain, uint256 amountOnSideChain, uint256 amount, string memory txOnSideChain) external returns (bool);
    function withdrawRequest(address sender, string memory recipientOnSideChain, uint256 amount) external returns (bool);
    function withdrawConfirm(uint256 burnProposalId, string memory txOnSideChain) external returns (bool);
    function migratePair(address newPair) external returns (bool);
}