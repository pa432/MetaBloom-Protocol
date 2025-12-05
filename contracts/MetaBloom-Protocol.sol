// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/*
 MetaBloom-Protocol.sol
 - ERC20 token "MetaBloom" with minting controlled by owner
 - Pausable transfers
 - Simple staking contract built into same contract:
     - stake() / withdraw() / claimRewards()
     - rewards accrue linearly based on rewardRate (per-second)
 - Owner can set reward rate and pause/unpause contract
 - Uses OpenZeppelin contracts (import statements below)
 
 NOTE:
 - This file imports OpenZeppelin contracts. When deploying you must have
   OpenZeppelin in your project (npm install @openzeppelin/contracts) or use Remix
   that fetches the imports.
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MetaBloom is ERC20, Ownable, Pausable, ReentrancyGuard {
    // --- Staking data structures ---
    struct StakeInfo {
        uint256 amount;           // tokens staked by user
        uint256 rewardDebt;      // rewards already accounted for (accumulated)
        uint256 lastUpdated;     // last timestamp user stake/rewards were updated
    }

    mapping(address => StakeInfo) public stakes;
    uint256 public totalStaked;

    // rewardRate: tokens rewarded per second per staked token scaled by 1e18
    // rewardRate is expressed as reward tokens per staked token per second, scaled
    // For example: rewardRate = 1e18 * 1 / (365*24*3600) ~ rewards of 1 token per token per year (not realistic)
    uint256 public rewardRate; // scaled by 1e18

    // Events
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);
    event TokensMinted(address indexed to, uint256 amount);

    // --- Constructor ---
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_
    ) ERC20(name_, symbol_) {
        if (initialSupply_ > 0) {
            _mint(msg.sender, initialSupply_);
            emit TokensMinted(msg.sender, initialSupply_);
        }

        // default rewardRate = 0 (owner must set)
        rewardRate = 0;
    }

    // --- ERC20 hooks: respect pausability ---
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "MetaBloom: token transfer while paused");
    }

    // --- Owner functions ---
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        // _rewardRate expressed scaled by 1e18
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // --- Staking logic ---
    // Internal helper to compute pending reward for user
    function _pendingReward(address user) internal view returns (uint256) {
        StakeInfo memory s = stakes[user];
        if (s.amount == 0) return 0;
        uint256 timeDiff = block.timestamp - s.lastUpdated;
        // reward = amount * rewardRate * timeDiff / 1e18
        // amount and rewardRate are uint256, multiplication safe in 0.8
        uint256 accrued = (s.amount * rewardRate * timeDiff) / 1e18;
        return accrued + s.rewardDebt;
    }

    // Update user's stake accounting before state changes
    function _updateRewards(address user) internal {
        StakeInfo storage s = stakes[user];
        if (s.amount > 0) {
            uint256 timeDiff = block.timestamp - s.lastUpdated;
            if (timeDiff > 0 && rewardRate > 0) {
                uint256 newAccrued = (s.amount * rewardRate * timeDiff) / 1e18;
                s.rewardDebt += newAccrued;
            }
        }
        s.lastUpdated = block.timestamp;
    }

    // Stake tokens: user must approve token transfer before calling
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "MetaBloom: cannot stake 0");
        // transfer tokens from user to this contract
        _transfer(msg.sender, address(this), amount);

        // update rewards first
        _updateRewards(msg.sender);

        stakes[msg.sender].amount += amount;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    // Withdraw staked tokens (optionally claim rewards)
    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        StakeInfo storage s = stakes[msg.sender];
        require(amount > 0, "MetaBloom: withdraw 0");
        require(s.amount >= amount, "MetaBloom: withdraw exceeds stake");

        // update rewards
        _updateRewards(msg.sender);

        s.amount -= amount;
        totalStaked -= amount;

        // transfer staked tokens back to user
        _transfer(address(this), msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    // Claim accumulated rewards (mints rewards to user)
    function claimRewards() external nonReentrant whenNotPaused {
        _updateRewards(msg.sender);
        StakeInfo storage s = stakes[msg.sender];
        uint256 reward = s.rewardDebt;
        require(reward > 0, "MetaBloom: no rewards");
        s.rewardDebt = 0;

        // mint reward tokens to user (owner-controlled asset inflation)
        _mint(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    // View helper: see pending rewards for user (not mutating)
    function pendingRewards(address user) external view returns (uint256) {
        StakeInfo memory s = stakes[user];
        if (s.amount == 0) return s.rewardDebt;
        uint256 timeDiff = block.timestamp - s.lastUpdated;
        uint256 accrued = (s.amount * rewardRate * timeDiff) / 1e18;
        return s.rewardDebt + accrued;
    }

    // Emergency withdraw: owner can rescue tokens mistakenly sent to contract (except staked portion)
    // WARNING: This removes liquidity; use carefully.
    function rescueERC20(address tokenAddress, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "MetaBloom: zero address");
        require(tokenAddress != address(this), "MetaBloom: cannot rescue native MetaBloom token");
        IERC20(tokenAddress).transfer(to, amount);
    }

    // Allow owner to force-update a user's lastUpdated (rare admin tool)
    function adminUpdateUserTimestamp(address user, uint256 newTimestamp) external onlyOwner {
        require(newTimestamp >= stakes[user].lastUpdated, "MetaBloom: new timestamp lower");
        stakes[user].lastUpdated = newTimestamp;
    }

    // --- Fallbacks ---
    receive() external payable {
        revert("MetaBloom: contract does not accept ETH");
    }
}
