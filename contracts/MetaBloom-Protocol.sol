// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MetaBloom Protocol (Corrected & Complete)
 * @dev A staking and reputation protocol rewarding community engagement and participation
 */
contract MetaBloomProtocol is Ownable {
    IERC20 public stakingToken;

    uint256 public totalStaked;
    uint256 public rewardPerStake;  // reward per token staked, scaled
    uint256 private constant magnitude = 2**128;

    struct Participant {
        uint256 stakedAmount;
        uint256 reputation;
        uint256 rewardDebt;  // used for reward calculation
        uint256 rewardsClaimed;
    }

    mapping(address => Participant) public participants;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event ReputationUpdated(address indexed user, uint256 newReputation);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardDistributed(uint256 totalReward);

    constructor(IERC20 _stakingToken) {
        stakingToken = _stakingToken;
    }

    /**
     * @dev Stake tokens and increase participant's staking balance and reputation
     */
    function stake(uint256 amount) external {
        require(amount > 0, "Stake more than zero");
        Participant storage user = participants[msg.sender];

        updateRewards();

        // Settle pending rewards before changing stake
        _harvestRewards(msg.sender);

        stakingToken.transferFrom(msg.sender, address(this), amount);
        user.stakedAmount += amount;

        // Increase reputation proportionally to stake
        user.reputation += amount / 1e18;  // example scaling for reputation
        user.rewardDebt = (user.stakedAmount * rewardPerStake) / magnitude;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
        emit ReputationUpdated(msg.sender, user.reputation);
    }

    /**
     * @dev Withdraw staked tokens and harvest rewards
     */
    function withdraw(uint256 amount) external {
        Participant storage user = participants[msg.sender];
        require(user.stakedAmount >= amount, "Withdraw exceeds stake");

        updateRewards();

        _harvestRewards(msg.sender);

        user.stakedAmount -= amount;
        user.rewardDebt = (user.stakedAmount * rewardPerStake) / magnitude;
        totalStaked -= amount;

        stakingToken.transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @dev Internal function to claim pending rewards
     */
    function _harvestRewards(address userAddr) internal {
        Participant storage user = participants[userAddr];
        uint256 accumulatedReward = (user.stakedAmount * rewardPerStake) / magnitude;
        uint256 pending = accumulatedReward - user.rewardDebt;

        if (pending > 0) {
            user.rewardsClaimed += pending;
            _rewardTokenTransfer(userAddr, pending);
            emit RewardClaimed(userAddr, pending);
        }
    }

    /**
     * @dev Placeholder function for reward token transfer
     * Assume rewards are paid in this token or ETH
     */
    function _rewardTokenTransfer(address recipient, uint256 amount) internal {
        // Transfer reward tokens or ETH. Placeholder: Implement as needed.
        // Example: transfer ETH (if rewards are ETH):
        // payable(recipient).transfer(amount);
        // Or transfer a reward ERC20 token:
        // rewardToken.transfer(recipient, amount);
        // For simplicity, this example is a placeholder.
    }

    /**
     * @dev Owner injects rewards to distribute among stakers
     */
    function distributeRewards(uint256 rewardAmount) external onlyOwner {
        require(totalStaked > 0, "No stakes");
        rewardPerStake += (rewardAmount * magnitude) / totalStaked;
        emit RewardDistributed(rewardAmount);
    }

    /**
     * @dev Check current accumulated reward per stake (for tracking)
     */
    function updateRewards() public view returns (uint256) {
        return rewardPerStake;
    }

    /**
     * @dev Get participant info
     */
    function getParticipant(address user) external view returns (
        uint256 stakedAmount,
        uint256 reputation,
        uint256 rewardsClaimed
    ) {
        Participant memory p = participants[user];
        return (p.stakedAmount, p.reputation, p.rewardsClaimed);
    }

    // Fallback to receive ETH rewards (if applicable)
    receive() external payable {}
}
