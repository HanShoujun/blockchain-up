// SPDX-License-Identifier:MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IUniswapV2.sol";
import "./IWETH.sol";
import "./ISwapRouter.sol";
import "./IUniswapV3Factory.sol";
import "./IUniswapV3Pool.sol";

contract MetadataQuery is Ownable {
    enum ArbType {
        none,
        univ2,
        univ3,
        sushiV2,
        sushiV3,
        pancakeV2,
        pancakeV3
    }

    constructor(address initialOwner) payable Ownable(initialOwner) {}

    function renounceOwnership() public override onlyOwner {}

    function withdrawEthAndTokens(address[] calldata tokenAddressList)
        external
        onlyOwner
    {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(owner()).transfer(balance);
        }
        uint256 lenght = tokenAddressList.length;

        for (uint256 i = 0; i < lenght; i++) {
            address token = tokenAddressList[i];
            balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) {
                // do not use safe transfer here to prevents revert by any shitty token
                IERC20(token).transfer(owner(), balance);
            }
        }
    }

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

    function checkTokenTax(
        address initToken,
        address checkToken,
        address router,
        address factory,
        uint8 arbType
    ) external {
        // require(revertStep > 1, "revert:1");
        uint256 initAmount = address(this).balance;

        IWETH(initToken).deposit{value: address(this).balance}();

        // checkToken balance before this
        uint256 thisBalanceBefore = IERC20(checkToken).balanceOf(address(this));
        uint256 amountOut;

        address[] memory tokens;
        tokens = new address[](2);
        tokens[0] = initToken;
        tokens[1] = checkToken;
        _approveRouter(router, tokens, false);
        if (
            arbType == uint8(ArbType.univ2) ||
            arbType == uint8(ArbType.sushiV2) ||
            arbType == uint8(ArbType.pancakeV2)
        ) {
            address[] memory routerPath;
            routerPath = new address[](2);
            routerPath[0] = initToken;
            routerPath[1] = checkToken;
            uint256[] memory amounts = _swapUniV2(
                router,
                initAmount,
                1,
                routerPath
            );
            amountOut = amounts[1];
        } else {
            uint24 fee = getFee(initToken,checkToken,factory);

            amountOut = _swapUniV3(
                router,
                initAmount,
                1,
                initToken,
                checkToken,
                fee
            );
        }

        require(amountOut > 0, "amountOut is 0 tax:true");

        require(
            IERC20(checkToken).balanceOf(address(this)) - thisBalanceBefore ==
                amountOut,
            "buy token error tax:true"
        );

        uint256 ownerTokenBalanceBefore = IERC20(checkToken).balanceOf(owner());

        IERC20(checkToken).transfer(owner(), amountOut);

        require(
            IERC20(checkToken).balanceOf(owner()) - ownerTokenBalanceBefore ==
                amountOut,
            "sell token error tax:true"
        );

        require(false, "tax:false");
    }

    function _approveRouter(
        address router,
        address[] memory tokens,
        bool force
    ) internal {
        // skip approval if it already has allowance and if force is false
        uint256 maxInt = type(uint256).max;

        uint256 tokensLength = tokens.length;

        for (uint8 i; i < tokensLength; ) {
            IERC20 token = IERC20(tokens[i]);
            uint256 allowance = token.allowance(address(this), router);
            if (allowance < (maxInt / 2) || force) {
                token.approve(router, maxInt);
            }

            unchecked {
                i++;
            }
        }
    }

    function _swapUniV2(
        address router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path
    ) internal returns (uint256[] memory amounts) {
        IUniswapV2Router router2 = IUniswapV2Router(router);
        amounts = router2.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            block.timestamp + 60
        );
    }

    function _swapUniV3(
        address router,
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        uint24 fee
    ) internal returns (uint256 amountOut) {
        ISwapRouter router3 = ISwapRouter(router);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp + 60,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            });
        amountOut = router3.exactInputSingle(params);
    }

    function getFee(
        address initToken,
        address checkToken,
        address factory
    ) internal view returns (uint24 fee) {
        address pool = address(0);
        uint128 maxLiquidity;
        uint24[5] memory list = [uint24(100), 500, 2500, 3000, 10000];
        for (uint8 i; i < list.length; ) {
            address tempPool = IUniswapV3Factory(factory).getPool(
                checkToken,
                initToken,
                list[i]
            );
            if (tempPool != address(0)) {
                uint128 liquidity = IUniswapV3Pool(tempPool).liquidity();
                if (liquidity > maxLiquidity) {
                    maxLiquidity = liquidity;
                    pool = tempPool;
                    fee = IUniswapV3Pool(pool).fee();
                }
            }
            unchecked {
                i++;
            }
        }
        require(pool != address(0), "no pool");
    }
}
