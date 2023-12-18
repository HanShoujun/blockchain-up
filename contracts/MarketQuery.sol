// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

abstract contract UniswapV2Factory  {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    function allPairsLength() external view virtual returns (uint);
}

struct MarketPair {
    address token0;
    address token1;
    address pairAddress;
    string symbol0;
    string symbol1;
}

contract BotsMarketQuery {

    function getDemoFunction(uint8 first, uint8 second) external pure returns (uint8) {
        return first+second;
    }
    

    function getReservesByPairs(IUniswapV2Pair[] calldata _pairs) external view returns (uint256[3][] memory) {
        uint256[3][] memory result = new uint256[3][](_pairs.length);
        for (uint i = 0; i < _pairs.length; i++) {
            (result[i][0], result[i][1], result[i][2]) = _pairs[i].getReserves();
        }
        return result;
    }

    function getPairsByIndexRange(UniswapV2Factory _uniswapFactory, uint256 _start, uint256 _stop) external view returns (address[3][] memory)  {
        uint256 _allPairsLength = _uniswapFactory.allPairsLength();
        if (_stop > _allPairsLength) {
            _stop = _allPairsLength;
        }
        require(_stop >= _start, "start cannot be higher than stop");
        uint256 _qty = _stop - _start;
        address[3][] memory result = new address[3][](_qty);
        for (uint i = 0; i < _qty; i++) {
            IUniswapV2Pair _uniswapPair = IUniswapV2Pair(_uniswapFactory.allPairs(_start + i));
            result[i][0] = _uniswapPair.token0();
            result[i][1] = _uniswapPair.token1();
            result[i][2] = address(_uniswapPair);
        }
        return result;
    }
}