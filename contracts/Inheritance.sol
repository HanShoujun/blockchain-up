// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract Storage {
    uint256 x;

    function setX(uint256 newX) public {
        x = newX;
    }

    function getX() public view virtual returns (uint256) {
        return x;
    }
}

contract Child is Storage {
    function getX() public view override returns (uint256) {
        return x;
    }

    function getX(uint256 add) public view returns (uint256) {
        return x + add;
    }
}

contract Caller {
    Storage store;
    Storage store2;

    constructor() {
        store = new Storage();
        store2 = new Storage();
    }

    function setX(uint256 x) public {
        store.setX(x);
    }

    function setX2(uint256 x) public {
        store2.setX(x);
    }
}
