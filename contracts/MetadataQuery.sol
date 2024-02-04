// SPDX-License-Identifier:MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MetadataQuery {

    function requeryTokenMetadata(address[] calldata tokenList)
        public
        view
        returns (string[3][] memory infoList)
    {
        uint256 length = tokenList.length;
        infoList = new string[3][](length);
        for (uint256 i = 0; i < length; i++) {
            address token = tokenList[i];
            string memory name = IERC20Metadata(token).name();
            string memory symbol = IERC20Metadata(token).symbol();
            uint8 decimals = IERC20Metadata(token).decimals();
            string memory decimalsStr = Strings.toString(uint256(decimals));
            infoList[i] = [name, symbol, decimalsStr];
        }
    }

    // function getAmountOut(
    //     uint256 amountIn,
    //     address pairAddress,
    //     bool buyToken0
    // ) public view returns (uint256 amountOut) {
    //     uint256 reserveIn;
    //     uint256 reserveOut;
    //     (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pairAddress)
    //         .getReserves();

    //     (reserveIn, reserveOut) = buyToken0
    //         ? (reserve1, reserve0)
    //         : (reserve0, reserve1);

    //     require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
    //     require(
    //         reserveIn > 0 && reserveOut > 0,
    //         "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
    //     );
    //     uint256 amountInWithFee = amountIn * (997);
    //     uint256 numerator = amountInWithFee * (reserveOut);
    //     uint256 denominator = reserveIn * (1000) + (amountInWithFee);
    //     amountOut = numerator / denominator;
    // }

}