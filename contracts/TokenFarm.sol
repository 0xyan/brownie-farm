// stake tokens
// unstake tokens
// addAllowedTokens
//getethValue

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenFarm is Ownable {
    mapping(address => bool) farmableTokens;
    address[] public farmableTokensArray;
    //mapping token -> staker -> amount
    mapping(address => mapping(address => uint)) public amountDeposited;
    mapping(address => uint) public uniqueTokensStaked;
    mapping(address => address) public tokenPriceFeedMapping;
    address[] public stakers;

    IERC20 internal dappToken;

    constructor(address _dappTokenAddress) {
        dappToken = IERC20(_dappTokenAddress);
    }

    function issueTokens() public {
        //issue tokens for all stakers
        for (uint i = 0; i < stakers.length; i++) {
            address recepient = stakers[i];
            uint userTotalValue = getUserTotalValue(recepient);
            dappToken.transfer(recepient, userTotalValue);
        }
    }

    // total value farmed from all pools for a user
    function getUserTotalValue(address _user) public view returns (uint) {
        uint totalValue = 0;
        require(uniqueTokensStaked[_user] > 0, "no tokens staked");
        for (uint i = 0; i < farmableTokensArray.length; i++) {
            totalValue =
                totalValue +
                getUserSingleTokenValue(_user, farmableTokensArray[i]);
        }
        return (totalValue);
    }

    // value of a single token in dollars
    function getUserSingleTokenValue(
        address _user,
        address _token
    ) public view returns (uint) {
        if (uniqueTokensStaked[_user] == 0) {
            return 0;
        }
        uint amount_tokens = amountDeposited[_token][_user];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            tokenPriceFeedMapping[_token]
        );
        (, int tokenPrice, , , ) = priceFeed.latestRoundData();
        uint decimals = uint(priceFeed.decimals());
        uint amountUSD = (amount_tokens * uint(tokenPrice)) / (10 ** decimals);
        return amountUSD;
    }

    function stakeTokens(uint _amount, address _token) public {
        require(_amount > 0, "Amount must be more than 0");
        require(tokenIsAllowed(_token), "Token is currently no allowed");
        //require(farmableTokens[_token] == true, "token is not allowed");
        //wrapping into interface
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        updateUniqueTokensStaked(msg.sender, _token);
        amountDeposited[_token][msg.sender] += _amount;
        // adding unique addresses to stakers list
        if (uniqueTokensStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
    }

    //mapping price feeds
    function addPriceFeedMappings(
        address _token,
        address _priceFeed
    ) public onlyOwner {
        tokenPriceFeedMapping[_token] = _priceFeed;
    }

    //tracks how many unique tokens each user staked
    function updateUniqueTokensStaked(address _user, address _token) internal {
        if (amountDeposited[_token][_user] < 0) {
            uniqueTokensStaked[_user] = uniqueTokensStaked[_user] + 1;
        }
    }

    function tokenIsAllowed(address _token) public view returns (bool) {
        for (uint256 i = 0; i < farmableTokensArray.length; i++) {
            if (farmableTokensArray[i] == _token) {
                return true;
            }
        }
        return false;
    }

    function unstakeTokens(address _token, uint _amount) public {
        require(
            amountDeposited[_token][msg.sender] > _amount,
            "not enough tokens staked"
        );
        amountDeposited[_token][msg.sender] -= _amount;
        IERC20(_token).transfer(msg.sender, _amount);
        uniqueTokensStaked[msg.sender] -= 1;
    }

    function addAllowedTokens(address _token) public onlyOwner {
        farmableTokensArray.push(_token);
    }
}
