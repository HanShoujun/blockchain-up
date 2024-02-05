// SPDX-License-Identifier:MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IUniswapV2.sol";
import "./IWETH.sol";

contract MetadataQuery is Ownable {
    constructor(address initialOwner) Ownable(initialOwner) payable {}

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
        address router
    ) external {
        // require(revertStep > 1, "revert:1");
        uint256 initAmount = address(this).balance;

        IWETH(initToken).deposit{value: address(this).balance}();

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

}
