// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './libraries/SafeMath.sol';
import './interfaces/IERC20.sol';
import './token/SafeERC20.sol';
import './access/Ownable.sol';
import "./ZudoToken.sol";

// MasterChef is the master of ZUDO. He can make ZUDO and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once ZUDO is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of ZUDOs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accZudoPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accZudoPerShare` (and `lastRewardTimestamp`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. ZUDOs to distribute per sec.
        uint256 lastRewardTimestamp;  // Last timestamp that ZUDOs distribution occurs.
        uint256 accZudoPerShare; // Accumulated ZUDOs per share, times 1e12. See below.
    }

    // The ZUDO TOKEN!
    ZudoToken public zudo;
    // Team address.
    address public teamAddr;
    // Percentage of pool rewards that goto the team.
    uint256 public teamPercent;
    // ZUDO tokens created per sec.
    uint256 public zudoPerSec;
    // Bonus muliplier for early zudo makers.
    uint256 public BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The timestamp when ZUDO mining starts.
    uint256 public startTimestamp;

    mapping (address => bool) public lpTokenAdded;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        ZudoToken _zudo,
        uint256 _zudoPerSec,
        uint256 _startTimestamp,
        address _teamAddr,
        uint256 _teamPercent
    ) {
        zudo = _zudo;
        zudoPerSec = _zudoPerSec;
        startTimestamp = _startTimestamp;
        teamAddr = _teamAddr;
        teamPercent = _teamPercent;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        require(lpTokenAdded[address(_lpToken)] == false, 'LP already added');
        lpTokenAdded[address(_lpToken)] = true;

        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTimestamp = block.timestamp > startTimestamp ? block.timestamp : startTimestamp;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardTimestamp: lastRewardTimestamp,
            accZudoPerShare: 0
        }));
    }

    // Update the given pool's ZUDO allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(_allocPoint);
        }
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending ZUDOs on frontend.
    function pendingZudo(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accZudoPerShare = pool.accZudoPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardTimestamp, block.timestamp);
            uint256 zudoReward = multiplier.mul(zudoPerSec).mul(pool.allocPoint).div(totalAllocPoint);
            accZudoPerShare = accZudoPerShare.add(zudoReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accZudoPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardTimestamp, block.timestamp);
        uint256 zudoReward = multiplier.mul(zudoPerSec).mul(pool.allocPoint).div(totalAllocPoint);
        zudo.mint(address(zudo), zudoReward);
        zudo.mint(teamAddr, zudoReward.mul(teamPercent).div(10000));
        pool.accZudoPerShare = pool.accZudoPerShare.add(zudoReward.mul(1e12).div(lpSupply));
        pool.lastRewardTimestamp = block.timestamp;
    }

    // Deposit LP tokens to MasterChef for ZUDO allocation.
    function deposit(uint256 _pid, uint256 _amount) public {

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accZudoPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeZudoTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            uint256 before = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            uint256 _after = pool.lpToken.balanceOf(address(this));
            _amount = _after.sub(before);

            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accZudoPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accZudoPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeZudoTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accZudoPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe ZUDO transfer function, just in case if rounding error causes pool to not have enough ZUDO.
    function safeZudoTransfer(address _to, uint256 _amount) internal {
        zudo.safeZudoTransfer(_to, _amount);
    }

    function setZudoPerSec(uint _value) public onlyOwner {
        massUpdatePools();
        zudoPerSec = _value;
    }
}