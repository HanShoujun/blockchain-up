// SPDX-License-Identifier:MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./IUniswapV2.sol";

contract JJArbi is Ownable {
    enum ArbType {
        none,
        univ2,
        univ3,
        sushiV2,
        sushiV3,
        pancakeV2,
        pancakeV3
    }

    event Withdrawn(address indexed to, uint256 indexed value);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function renounceOwnership() public override onlyOwner {}

    function withdrawEthAndTokens(address[] calldata tokenAddressList)
        external
        onlyOwner
    {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(owner()).transfer(balance);
            emit Withdrawn(owner(), balance);
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

    receive() external payable {}

    fallback() external payable {}

    function executeArbi(
        address baseToken,
        uint256 baseAmount,
        address[3][] calldata pathList,
        uint8[] calldata typeList
    ) external payable onlyOwner {
        require(
            pathList.length == typeList.length,
            "Params Error, pathList and typeList diffrent length"
        );

        uint256 balanceBefore = IERC20(baseToken).balanceOf(address(this));
        require(
            balanceBefore >= baseAmount,
            "Arbitrage fail, no enough base token"
        );

        uint256 amountOut = baseAmount;
        uint256 pathLength = pathList.length;

        for (uint8 i = 0; i < pathLength; ) {
            address[3] memory path = pathList[i];
            address router = path[0];
            address tokenIn = path[1];
            address tokenOut = path[2];
            uint8 arbType = typeList[i];

            address[] memory tokens;
            tokens = new address[](2);
            tokens[0] = tokenIn;
            tokens[1] = tokenOut;
            _approveRouter(router, tokens, false);

            address[] memory routerPath;
            routerPath = new address[](2);
            routerPath[0] = tokenIn;
            routerPath[1] = tokenOut;

            if (
                arbType == uint8(ArbType.univ2) ||
                arbType == uint8(ArbType.sushiV2) ||
                arbType == uint8(ArbType.pancakeV2)
            ) {
                uint256[] memory amounts = _swapUniV2(
                    router,
                    amountOut,
                    1,
                    routerPath
                );
                amountOut = amounts[1];
            } else {
                require(false, "unknown parse type");
            }

            unchecked {
                i++;
            }
        }

        // Calculate profit
        uint256 balanceAfter = IERC20(baseToken).balanceOf(address(this));
        require(balanceAfter > balanceBefore, "Arbitrage fail, Losing money");
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

    function checkTokenTax(
        address initToken,
        address checkToken,
        address router,
        uint256 initAmount
    ) external onlyOwner {
        // require(revertStep > 1, "revert:1");
        // approve router
        address[] memory tokens;
        tokens = new address[](2);
        tokens[0] = initToken;
        tokens[1] = checkToken;
        _approveRouter(router, tokens, false);

        // checkToken balance before this
        uint256 thisBalanceBefore = IERC20(checkToken).balanceOf(address(this));

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

        uint256 thisBalanceAfter = IERC20(checkToken).balanceOf(address(this));

        require(thisBalanceAfter - thisBalanceBefore == amounts[1], "tax:true");
        require(false, "tax:false");
    }

    
}
