// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MetaBloom Protocol
 * @dev A decentralized growth protocol enabling users to stake tokens and earn rewards over time.
 * Designed for DeFi and Web3 ecosystems.
 */
contract MetaBloomProtocol {
    address public owner;
    uint256 public totalStaked;
    uint256 public rewardRate = 5; // 5% reward rate

    struct StakeInfo {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => StakeInfo) public stakes;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Allows users to stake ETH into the protocol.
     */
    function stake() external payable {
        require(msg.value > 0, "Stake amount must be greater than zero");
        stakes[msg.sender].amount += msg.value;
        stakes[msg.sender].timestamp = block.timestamp;
        totalStaked += msg.value;

        emit Staked(msg.sender, msg.value);
    }

    /**
     * @dev Unstake function lets users withdraw staked ETH plus rewards.
     */
    function unstake() external {
        StakeInfo memory userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No funds staked");

        uint256 stakingDuration = block.timestamp - userStake.timestamp;
        uint256 reward = (userStake.amount * rewardRate * stakingDuration) / (100 * 365 days);
        uint256 totalReturn = userStake.amount + reward;

        totalStaked -= userStake.amount;
        delete stakes[msg.sender];

        payable(msg.sender).transfer(totalReturn);
        emit Unstaked(msg.sender, reward);
    }

    /**
     * @dev Owner can update the reward rate.
     */
    function updateRewardRate(uint256 _newRate) external {
        require(msg.sender == owner, "Only owner can update reward rate");
        rewardRate = _newRate;
        emit RewardRateUpdated(_newRate);
    }

    /**
     * @dev Returns the current staked amount and duration for a user.
     */
    function getStakeDetails(address _user) external view returns (uint256, uint256) {
        return (stakes[_user].amount, block.timestamp - stakes[_user].timestamp);
    }
}

