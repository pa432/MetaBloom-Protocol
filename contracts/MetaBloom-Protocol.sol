reward per token staked, scaled
    uint256 private constant magnitude = 2**128;

    struct Participant {
        uint256 stakedAmount;
        uint256 reputation;
        uint256 rewardDebt;  Settle pending rewards before changing stake
        _harvestRewards(msg.sender);

        stakingToken.transferFrom(msg.sender, address(this), amount);
        user.stakedAmount += amount;

        example scaling for reputation
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
        Example: transfer ETH (if rewards are ETH):
        Or transfer a reward ERC20 token:
        For simplicity, this example is a placeholder.
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

    End
End
End
End
// 
// 
End
// 
