// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenFarm is Ownable {
    // mapping tokenaddress -> stakeraddress -> amount
    mapping (address => mapping(address => uint256)) public stakingBalance;
    mapping (address => uint256) public uniqueTokensStaked;
    mapping (address => address) public tokenPriceFeedMapping;
    address[] public stakers;
    address[] public allowedTokens;
    IERC20 public dappToken;

    constructor(address _dappTokenAddress) public {
        dappToken = IERC20(_dappTokenAddress);
    }
    // Stake Tokens
    // UnStake Tokens
    // Issue Tokens
    // Add Allowed Tokens
    // Get \Value

    function setPriceFeedContract(address _token, address _priceFeed) public onlyOwner {
        tokenPriceFeedMapping[_token] = _priceFeed;
    }
    // 100 ETH 1:1, for every 1 ETH, we give 1 DappToken
    // 50 ETH 50 DAI staked, want to give 1 DappToken / DAI --> need conversion
    function issueTokens() public onlyOwner {
        // Issue tokens to all stakers
        for (uint256 i; i < stakers.length; i++) {
            address recipient = stakers[i];
            uint256 userTotalValue = getUserTotalValue(recipient);
            dappToken.transfer(recipient, userTotalValue); // Balance += $$ Locked Value
        }

    }
    function getUserTotalValue(address _user) public view returns (uint256) {
        uint256 totalValue = 0;
        require(uniqueTokensStaked[_user] > 0, "No tokens staked!");
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            totalValue += getUserSingleTokenValue(_user, allowedTokens[i]);
        }
        return totalValue;

    }
    function getUserSingleTokenValue(address _user, address _token) public view returns (uint256) {
        // if (uniqueTokensStaked[_user] <= 0) {
        //     return 0;
        // }

        // price of token * stakingBalance[_token][user]
        getTokenValue(_token);
        (uint256 price, uint256 decimals) = getTokenValue(_token);
        return (stakingBalance[_token][_user] * price / (10**decimals)); // $ Value of a particular token stake account, maintain 18 decimals
    }
    function getTokenValue(address _token) public view returns (uint256, uint256) {
        address priceFeedAddress = tokenPriceFeedMapping[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        (,int256 price,,,) = priceFeed.latestRoundData();
        uint256 decimals = priceFeed.decimals();
        return (uint256(price), decimals);
    }
    function stakeTokens(uint256 _amount, address _token) public {
        // Which tokens can they stake?
        // How much?

        require(_amount > 0, "Amoung must be more than 0");
        require(tokenIsAllowed(_token), "Token not listed in exchange");

        // transferFrom erc20 contract to tokenfarm contract
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        updateUniqueTokensStaked(msg.sender, _token);
        stakingBalance[_token][msg.sender] += _amount;
        if (uniqueTokensStaked[msg.sender] == 1) { // First token staked, interaction w/ contract
            stakers.push(msg.sender);
        }
        
    }
    function updateUniqueTokensStaked(address _user, address _token) internal {
        if (stakingBalance[_token][_user] <= 0) {
            uniqueTokensStaked[_user] += 1;
        }
    }
    function addAllowedTokens(address _token) public onlyOwner {
        allowedTokens.push(_token);
    }
    function tokenIsAllowed(address _token) public returns (bool) {
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            if (allowedTokens[i] == _token) {
                return true;
            }
        }
        return false;
    }

    function unstakeTokens(address _token) public {
        uint256 balance = stakingBalance[_token][msg.sender];
        require(balance > 0, "Staking balance cannot be 0");
        IERC20(_token).transfer(msg.sender, balance); // Withdraw stake from IERC20 contract to user
        stakingBalance[_token][msg.sender] = 0;
        uniqueTokensStaked[msg.sender] -= 1;
    }
}