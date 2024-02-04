// SPDX-License-Identifier:MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./IUniswapV2.sol";
import "./IUniswapV2Pair.sol";


/// Unkown arbitrage type
/// `arbType` .
/// @param arbType arbitrage type.
error UnkownArbType(uint8 arbType);

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

    // Add the library methods
    using SafeERC20 for IERC20;

    // ArbType public constant defaultType = ArbType.univ2;

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

    function depositToken(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(0), "invalid token address");
        require(amount > 0, "invalid amount");
        uint256 senderBalance = IERC20(tokenAddress).balanceOf(msg.sender);
        require(senderBalance > amount, "insufficient token for transfer");

        require(
            IERC20(tokenAddress).transferFrom(
                msg.sender,
                address(this),
                amount
            ),
            "transfer failed"
        );
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
                revert UnkownArbType(arbType);
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
    ) public {
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

    function requeryTokenMetadata(address[] calldata tokenList)
        public
        view
        returns (string[3][] memory infoList)
    {
        uint256 length = tokenList.length;
        infoList = new string[3][](length);
        for (uint256 i = 0; i < length; i++) {
            address token = tokenList[i];
            string memory name = ERC20(token).name();
            string memory symbol = ERC20(token).symbol();
            uint8 decimals = ERC20(token).decimals();
            string memory decimalsStr = Strings.toString(uint256(decimals));
            infoList[i] = [name, symbol, decimalsStr];
        }
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

    function getAmountOut(
        uint256 amountIn,
        address pairAddress,
        bool sellToken0
    ) public view returns (uint256 amountOut) {
        (uint256 reserveIn,uint256 reserveOut, ) = IUniswapV2Pair(pairAddress).getReserves();
        if(sellToken0){
            (reserveOut,reserveIn, ) = IUniswapV2Pair(pairAddress).getReserves();
        }

        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint256 amountInWithFee = amountIn*(997);
        uint256 numerator = amountInWithFee*(reserveOut);
        uint256 denominator = reserveIn*(1000)+(amountInWithFee);
        amountOut = numerator / denominator;
    }

}
