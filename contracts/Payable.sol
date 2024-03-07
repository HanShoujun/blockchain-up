// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract Payable {
    uint256 public received;

    uint256 public fallbackReceived;

    uint public payReceived;

    bytes public bstr;

    function pay() external payable  {
        payReceived += msg.value;
    }

    receive() external payable {
        received += msg.value;
    }

    fallback() external payable {
        fallbackReceived += msg.value;
    }

    function teststr() public returns (string memory) {
        bstr.push('1');
        return string(bstr);
    }

    uint public sum;
    uint constant sumTo = 1000000;

    function addInteger() public  {
        for (uint i = 1; i <= sumTo; i++) 
        {
            sum += i;
        }
    }

    function time() public view returns (uint256 ctime) {
        ctime = block.timestamp + 60;
    }
}
