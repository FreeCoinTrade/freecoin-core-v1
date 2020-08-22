// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "FreePair.sol";

contract FreeFactory {

    using SafeMath for uint256;

    uint256 public tokenCount;
    mapping(address => address) public tokenToPair; // todo: add name
    mapping(address => address) public pairToToken; // todo: add name
    mapping(uint256 => address) public idToToken;

    mapping (address => bool) public notaryMap;
    address[] public notaryList;
    uint256 public notaryCount;

    event NewPair(address creator, address token, uint256 pair); // todo: add name

    constructor (address[] memory notary) public {
        notaryList = notary;
        for (uint256 i = 0; i < notary.length; i++) {
             notaryMap[notary[i]] = true;
        }
        notaryCount = notary.length;
    }

    function createPair(string memory sideChainName, address token) public returns (address) {
        require(notaryMap[msg.sender], "this can only be called by notary");
        require(token != address(0), "token cann't be zero address");
        require(tokenToPair[token] == address(0), "this token pair has existed");
        address pair = new FreePair(sideChainName, token);
        tokenToPair[token] = pair;
        pairToToken[pair] = token;
        uint256 tokenId = tokenCount + 1;
        tokenCount = tokenId;
        idToToken[tokenId] = token;
        emit NewPair(msg.sender, token, pair);
        return pair;
    }
}