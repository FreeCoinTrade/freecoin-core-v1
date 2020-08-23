// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IFreeFactory {
    
    event NewPair(address creator, address token, address pair); // todo: add name

    function notaryMap(address notary) external view returns (bool);
    function notaryCount() external view returns (uint256);
    function createPair(string memory sideChainName, address token) external returns (address);
}