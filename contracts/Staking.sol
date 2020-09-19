pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./StakingAccessInterface.sol";

/**
 * @title Staking
 * @dev Staking contract for the Orion Protocol
 * @author @EmelyanenkoK
 */
contract Staking is Ownable {

    using SafeMath for uint256;

    enum StakePhase{ NOTSTAKED, LOCKING, LOCKED, RELEASING, READYTORELEASE, FROZEN }

    struct Stake {
      uint256 amount;
      StakePhase phase;
      uint64 lastActionTimestamp;
    }

    uint64 constant lockingDuration = 3600*24;
    uint64 constant releasingDuration = 3600*24;

    //Asset for staking
    IERC20 baseAsset;
    StakingAccessInterface _exchange;

    // Get user balance by address and asset address
    mapping(address => Stake) private stakingData;
    //mapping(address => mapping(address => uint256)) virtual assetBalances;


    constructor(address orionTokenAddress) public {
        baseAsset = IERC20(orionTokenAddress);
    }

    function setExchangeAddress(address exchange) external onlyOwner {
        _exchange = StakingAccessInterface(exchange);
    }


    function moveFromBalance(uint256 amount) internal {
        require(baseAsset.transferFrom(address(_exchange), address(this), amount), "E6");
        _exchange.moveToStake(_msgSender(),amount);
        Stake storage stake = stakingData[_msgSender()];
        stake.amount = stake.amount.add(amount);
    }

    function moveToBalance() internal {
        Stake storage stake = stakingData[_msgSender()];
        require(baseAsset.transfer(address(_exchange), stake.amount), "E6");
        _exchange.moveFromStake(_msgSender(), stake.amount);
        stake.amount = 0;
    }

    function seizeFromStake(address user, address receiver, uint256 amount) external {
        require(_msgSender() == address(_exchange), "Unauthorized seizeFromStake");
        Stake storage stake = stakingData[user];
        stake.amount = stake.amount.sub(amount);
        require(baseAsset.transfer(address(_exchange), amount), "E6");
        _exchange.moveFromStake(receiver, amount);
    }


    function lockStake(uint256 amount) external {
        assert(getStakePhase(_msgSender()) == StakePhase.NOTSTAKED); // TODO do we need this?
        moveFromBalance(amount);
        Stake storage stake = stakingData[_msgSender()];
        stake.phase = StakePhase.LOCKING;
        stake.lastActionTimestamp = uint64(now);
    }

    function requestReleaseStake() external {
        StakePhase currentPhase = getStakePhase(_msgSender());
        if(currentPhase == StakePhase.LOCKING || currentPhase == StakePhase.READYTORELEASE) {
          moveToBalance();
          Stake storage stake = stakingData[_msgSender()];
          stake.phase = StakePhase.NOTSTAKED;
        } else if (currentPhase == StakePhase.LOCKED) {
          Stake storage stake = stakingData[_msgSender()];
          stake.phase = StakePhase.RELEASING;
          stake.lastActionTimestamp = uint64(now);
        } else {
          revert("Can not release funds from this phase");
        }

    }

    function postponeStakeRelease(address user) external onlyOwner{
        Stake storage stake = stakingData[user];
        stake.phase = StakePhase.FROZEN;
    }

    function allowStakeRelease(address user) external onlyOwner {
        Stake storage stake = stakingData[user];
        stake.phase = StakePhase.READYTORELEASE;
    }

    function seize(address user, address receiver) external onlyOwner {
    }

    function getStake(address user) public view returns (Stake memory){
        Stake memory stake = stakingData[user];
        if(stake.phase == StakePhase.LOCKING && (now - stake.lastActionTimestamp) > lockingDuration) {
          stake.phase = StakePhase.LOCKED;
        } else if(stake.phase == StakePhase.RELEASING && (now - stake.lastActionTimestamp) > releasingDuration) {
          stake.phase = StakePhase.READYTORELEASE;
        }
        return stake;
    }

    function getStakeBalance(address user) public view returns (uint256) {
        return getStake(user).amount;
    }

    function getStakePhase(address user) public view returns (StakePhase) {
        return getStake(user).phase;
    }

    function getLockedStakeBalance(address user) public view returns (uint256) {
      Stake memory stake = getStake(user);
      if(stake.phase == StakePhase.LOCKED || stake.phase == StakePhase.FROZEN)
        return stake.amount;
      return 0;
    }
}
