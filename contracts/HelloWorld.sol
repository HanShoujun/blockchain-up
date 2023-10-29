// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract HelloWorld {
    uint256 number;

    function store(uint256 num) public {
        number = num;
    }

    function get() public view returns (uint256) {
        return number;
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function viewBlockNumber() public view returns (uint) {
        return block.timestamp;
    }

    function viewMessage() public view returns (address) {
        return msg.sender;
    }

    function viewTx() public view returns (address) {
        return tx.origin;
    }

}