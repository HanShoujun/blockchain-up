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
    

    function getPairsByIndexRange(UniswapV2Factory _uniswapFactory, uint256 _start, uint256 _stop) external view returns (MarketPair[] memory)  {
        uint256 _allPairsLength = _uniswapFactory.allPairsLength();
        if (_stop > _allPairsLength) {
            _stop = _allPairsLength;
        }
        require(_stop >= _start, "start cannot be higher than stop");
        uint256 _qty = _stop - _start;
        MarketPair[] memory result = new MarketPair[](_qty);
        for (uint i = 0; i < _qty; i++) {
            IUniswapV2Pair _uniswapPair = IUniswapV2Pair(_uniswapFactory.allPairs(_start + i));
            MarketPair memory pair;
            pair.token0 = _uniswapPair.token0();
            pair.token1 = _uniswapPair.token1();
            pair.pairAddress = address(_uniswapPair);
            IERC20 token0 = IERC20(_uniswapPair.token0());
            IERC20 token1 = IERC20(_uniswapPair.token1());
            pair.symbol0 = token0.symbol();
            pair.symbol1 = token1.symbol();
            result[i] = pair;
        }
        return result;
    }
}