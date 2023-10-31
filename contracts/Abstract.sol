

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

abstract contract AbstractMath {
    
    function return1() public pure returns (uint) {
        return 1;
    }

    function getValue() public virtual view returns (uint);

    function add5() public view returns (uint){
        return getValue()+5;
    }

}

contract Math is AbstractMath {

    uint x;

    function setX(uint newX) public {
        x = newX;
    }
    
    function getValue() public override view returns (uint){
        return x;
    }

}