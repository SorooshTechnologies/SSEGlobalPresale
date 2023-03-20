// SPDX-License-Identifier: MIT

// Developed By www.soroosh.app

// SSE Global Presale Contract

pragma solidity ^0.8.16;

import "./DataFeeds.sol";
import "./Ownable.sol";

interface IBEP20 {
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract SSEGlobalPresale is DataFeeds, Ownable {
    // presale status
    bool public isActive;

    // min and max amount
    uint public immutable minTokenAmount;
    uint public immutable maxTokenAmount;
    uint public constant TOKEN_PRICE = 0.015 * 10 ** 18;

    // financial report
    uint public totalTokenSale;
    uint public totalBNBValue;

    // list of wallets that have entered the presale
    mapping(address => uint) walletTokenAllocation;
    mapping(address => uint) walletBNBAllocation;

    IBEP20 private immutable _token;

    constructor(IBEP20 token_, uint minAmount_, uint maxAmount_) {
        _transferOwnership(msg.sender);
        _token = token_;
        minTokenAmount = minAmount_ * 10 ** 18;
        maxTokenAmount = maxAmount_ * 10 ** 18;
    }

    // =============== Activation and DeActivating Of Presale ============== \\

    function activate() public onlyOwner {
        isActive = true;
    }

    function deActivate() public onlyOwner {
        isActive = false;
    }

    // =============== Functions For Calculating Amount ============== \\

    /// @dev Gets bnb last price
    function getBNBLatestPrice() public view returns (uint) {
        return uint(_getLatestPrice() / 1e8);
    }

    /// @dev converts BNB TO USD.
    /// @param value amount of BNB.
    function calulateUsd(uint value) private view returns (uint) {
        uint bnbPrice = getBNBLatestPrice();
        return value * bnbPrice;
    }

    /// @dev converts BNB TO SSE Amount.
    /// @param value amount of BNB.
    function getTokenAmountFromBNB(uint value) private view returns (uint) {
        uint _toUsdt = calulateUsd(value) * 10 ** 18;
        return _toUsdt / TOKEN_PRICE;
    }

    /// @dev converts SSE to BNB amount.
    /// @param amount amount of token.
    function getBNBAmountFromToken(uint amount) public view returns (uint) {
        uint _BNBPrice = getBNBLatestPrice();
        uint _toUSDT = amount * TOKEN_PRICE;
        return _toUSDT / _BNBPrice;
    }

    // =============== Functions For Checking Boundaries ============== \\

    /// @dev checks if amount of BNB is in presale boundry.
    /// @param value amount of BNB.
    function checkBNBAmount(uint value) private view returns (bool) {
        uint _toUsdt = calulateUsd(value) * 10 ** 18;
        uint totalAmount = _toUsdt / TOKEN_PRICE;
        if (totalAmount >= minTokenAmount && totalAmount <= maxTokenAmount) {
            return true;
        }
        return false;
    }

    /// @dev returns the amount of tokens which user has already bought.
    /// @param address_ address of the wallet.
    function getWalletTokenParticipation(
        address address_
    ) public view returns (uint) {
        return walletTokenAllocation[address_];
    }

    /// @dev returns the amount of bnb which user has already entered with.
    /// @param address_ address of the wallet.
    function getWalletBNBParticipation(
        address address_
    ) public view returns (uint) {
        return walletBNBAllocation[address_];
    }

    /// @dev checks if user can buy more token.
    /// @param amount amount token.
    function checkParticipationUpdate(uint amount) private view returns (bool) {
        uint entered = getWalletTokenParticipation(msg.sender);
        if (maxTokenAmount > entered) {
            uint left = maxTokenAmount - entered;
            return uint(left) >= amount;
        }
        return false;
    }

    /// @dev main function to enter presalse -- will check if already participated and will update the amount.

    function enterPresale() public payable {
        require(
            isActive,
            "SSEGlobalPresale : Presale is currently not active."
        );

        if (getWalletTokenParticipation(msg.sender) == 0) {
            require(
                checkBNBAmount(msg.value),
                "SSEGlobalPresale : Amount is not valid"
            );
            uint amount = getTokenAmountFromBNB(msg.value);
            walletTokenAllocation[msg.sender] = amount;
            walletBNBAllocation[msg.sender] = msg.value;
            totalTokenSale += amount;
            totalBNBValue += msg.value;
            sendTokenToWallet(amount, msg.sender);
        } else {
            // we need to know how much left and will calculate the amount needed for the transaction !
            uint amount = getTokenAmountFromBNB(msg.value);
            require(
                checkParticipationUpdate(amount),
                "SSEGlobalPresale: Amount Provided is not acceptable."
            );
            walletTokenAllocation[msg.sender] += amount;
            walletBNBAllocation[msg.sender] += msg.value;
            totalTokenSale += amount;
            totalBNBValue += msg.value;
            sendTokenToWallet(amount, msg.sender);
        }
    }

    // =============== Transfering And Withdraw Methods ============== \\

    /// @dev withdraws token from contract.
    /// @param amount amount token.
    /// @param beneficiary_ destination address.
    function withdrawToken(
        uint256 amount,
        address beneficiary_
    ) public onlyOwner {
        require(token().transfer(beneficiary_, amount));
    }

    /// @dev withdraws BNB from contract.
    /// @param to destination address.
    function withdrawBNB(address payable to) public payable onlyOwner {
        require(
            to != address(0),
            "SSEGlobalPresale : destinatino is zero address"
        );
        uint Balance = address(this).balance;
        require(
            Balance > 0 wei,
            "SSEGlobalPresale : Error! No Balance to withdraw"
        );
        to.transfer(Balance);
    }

    /// @dev sent token to wallet.
    /// @param amount amount of token.
    /// @param destinatino_ destination address.
    function sendTokenToWallet(
        uint amount,
        address destinatino_
    ) private returns (bool) {
        require(
            token().transfer(destinatino_, amount),
            "SSEGlobalPresale : withdraw error."
        );
        return true;
    }

    function token() public view returns (IBEP20) {
        return _token;
    }
}
