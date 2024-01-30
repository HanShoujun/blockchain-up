// SPDX-License-Identifier:UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./IUniswapV2.sol";


/// Unkown arbitrage type 
/// `arbType` .
/// @param arbType arbitrage type.
error UnkownArbType(uint8 arbType);

contract JJArbi is Ownable {

    enum ArbType { none, univ2, univ3 }

    event Withdrawn(address indexed to, uint256 indexed value);
    event BaseTokenAdded(address indexed token);
    event BaseTokenRemoved(address indexed token);

    using SafeERC20 for IERC20;
    // Add the library methods
    using EnumerableSet for EnumerableSet.AddressSet;


    // AVAILABLE BASE TOKENS
    EnumerableSet.AddressSet baseTokens;
    ArbType public constant defaultType = ArbType.univ2;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(owner()).transfer(balance);
            emit Withdrawn(owner(), balance);
        }

        for (uint256 i = 0; i < baseTokens.length(); i++) {
            address token = baseTokens.at(i);
            balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) {
                // do not use safe transfer here to prevents revert by any shitty token
                IERC20(token).transfer(owner(), balance);
            }
        }
    }

    function addBaseToken(address token) external onlyOwner {
        baseTokens.add(token);
        emit BaseTokenAdded(token);
    }

    function removeBaseToken(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            // do not use safe transfer to prevents revert by any shitty token
            IERC20(token).transfer(owner(), balance);
        }
        baseTokens.remove(token);
        emit BaseTokenRemoved(token);
    }

    function getBaseTokens() external view returns (address[] memory tokens) {
        uint256 length = baseTokens.length();
        tokens = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            tokens[i] = baseTokens.at(i);
        }
    }

    receive() external payable {
    }

    fallback() external payable {
    }

    function executeArbi(address baseToken, uint256 baseEthPrice, uint256 baseAmount, address[3][] calldata pathList, uint8[] calldata typeList) external payable onlyOwner returns (uint amountOut, uint256 gasUsed) {
        require(pathList.length == typeList.length, "Params Error, pathList and typeList diffrent length");
        uint256 startGas = gasleft();

        uint256 balanceBefore = IERC20(baseToken).balanceOf(address(this));
        require(balanceBefore > baseAmount, "Arbitrage fail, no enough base token");

        amountOut = baseAmount;

        uint pathLength = pathList.length;

        for (uint8 i = 0; i < pathLength;) {
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


            if (arbType == uint8(ArbType.univ2)) {

                uint[] memory amounts = _swapUniV2(router, amountOut, 0, tokens);
                amountOut = amounts[1];

            }else {
                revert UnkownArbType(arbType);
            }

            unchecked {
                i++;
            }
        }

        gasUsed = startGas - gasleft();

        // Calculate profit
        uint256 balanceAfter = IERC20(baseToken).balanceOf(address(this));
        require(balanceAfter > balanceBefore, "Arbitrage fail, Losing money");
        uint256 costBaseToken = gasUsed * 11 / 10 / baseEthPrice;
        require(balanceAfter - balanceBefore - costBaseToken > 0, "Arbitrage fail, profit is less than cost");

    }

    function _approveRouter(
        address router,
        address[] memory tokens,
        bool force
    ) internal {
        // skip approval if it already has allowance and if force is false
        uint maxInt = type(uint256).max;

        uint tokensLength = tokens.length;

        for (uint8 i; i < tokensLength; ) {
            IERC20 token = IERC20(tokens[i]);
            uint allowance = token.allowance(address(this), router);
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
        uint amountIn,
        uint amountOutMin,
        address[] memory path
    ) internal returns (uint[] memory amounts) {

        IUniswapV2Router router2 = IUniswapV2Router(router);
        amounts = router2.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            block.timestamp + 60
        );
    }

}