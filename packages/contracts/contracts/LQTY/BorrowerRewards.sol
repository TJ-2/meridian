// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../Dependencies/BaseMath.sol";
import "../Dependencies/SafeMath.sol";
import "../Dependencies/Ownable.sol";
import "../Dependencies/CheckContract.sol";
import "../Dependencies/console.sol";

import "../Interfaces/IBATToken.sol";
import "../Interfaces/IBorrowerRewards.sol";
import "../Dependencies/LiquityMath.sol";
import "../Interfaces/ISTLOSToken.sol";
import "../Interfaces/ITroveManager.sol";

contract BorrowerRewards is IBorrowerRewards, Ownable, CheckContract, BaseMath {
    using SafeMath for uint;

    // --- Data ---
    string constant public NAME = "BorrowerRewards";

    mapping( address => uint) public stakes;
    uint public totalTroveDeposits;

    uint public F_STLOS; // Running sum of STLOS fees per-BAT-staked

    // User snapshots of F_STLOS, taken at the point at which their latest deposit was made
    mapping (address => Snapshot) public snapshots; 

    struct Snapshot {
        uint F_STLOS_Snapshot;
    }
    
    IBATToken public BATToken;
    ISTLOSToken public stlosToken;
    ITroveManager public troveManager;

    address public troveManagerAddress;
    address public borrowerOperationsAddress;
    address public activePoolAddress;

    // --- Events ---

    event BATTokenAddressSet(address _BATTokenAddress);
    event STLOSTokenAddressSet(address _stlosTokenAddress);
    event TroveManagerAddressSet(address _troveManager);
    event BorrowerOperationsAddressSet(address _borrowerOperationsAddress);
    event ActivePoolAddressSet(address _activePoolAddress);

    event StakeChanged(address indexed staker, uint newStake);
    event StakingGainsWithdrawn(address indexed staker, uint STLOSGain);
    event F_STLOSUpdated(uint _F_STLOS);
    event TotalBATStakedUpdated(uint _totalTroveDeposits);
    event StakerSnapshotsUpdated(address _staker, uint _F_STLOS);

    // --- Functions ---

    function setAddresses
    (
        address _BATTokenAddress,
        address _stlosTokenAddress,
        address _troveManagerAddress, 
        address _borrowerOperationsAddress,
        address _activePoolAddress
        
    ) 
        external 
        onlyOwner 
        override 
    {
        checkContract(_BATTokenAddress);
        checkContract(_stlosTokenAddress);
        checkContract(_troveManagerAddress);
        checkContract(_borrowerOperationsAddress);
        checkContract(_activePoolAddress);

        BATToken = IBATToken(_BATTokenAddress);
        stlosToken = ISTLOSToken(_stlosTokenAddress);
        troveManagerAddress = _troveManagerAddress;
        borrowerOperationsAddress = _borrowerOperationsAddress;
        activePoolAddress = _activePoolAddress;

        emit TroveManagerAddressSet(_troveManagerAddress);
        emit BorrowerOperationsAddressSet(_borrowerOperationsAddress);
        emit ActivePoolAddressSet(_activePoolAddress);

        _renounceOwnership();
    }

    // If caller has a pre-existing stake, send any accumulated STLOS gains to them. 
    function stake(uint _BATamount, address _user) external override {

        _requireNonZeroAmount(_BATamount);

        uint currentStake = stakes[_user];

        uint STLOSGain;
        // Grab any accumulatedSTLOS gains from the current stake
        if (currentStake != 0) {
            STLOSGain = _getPendingSTLOSGain(_user);
        }
    
       _updateUserSnapshots(_user);

        uint newStake = currentStake.add(_BATamount);

        // Increase user’s stake and total BAT staked
        stakes[_user] = newStake;
        totalTroveDeposits = totalTroveDeposits.add(_BATamount);
        emit TotalBATStakedUpdated(totalTroveDeposits);

        // Transfer BAT from caller to this contract.       !!!
        // TLOSToken.sendToBorrowerRewards(msg.sender, _TLOSamount);

        // Here we need to create a virtual token that is minted and burned on trove operations

        emit StakeChanged(_user, newStake);
        emit StakingGainsWithdrawn(_user, STLOSGain);

         // Send accumulated STLOS  gains to the caller
        if (currentStake != 0) {
            stlosToken.transfer(_user, STLOSGain);
        }
    }

    // Unstake the tokens and send the it back to the BorrowerOperations contract, along with their accumulated STLOS gains. 
    // If requested amount > stake, send their entire stake.
    function unstake(uint _BATamount, address _user) external override {

        uint currentStake = stakes[_user];
        _requireUserHasStake(currentStake);

        // Grab any accumulated STLOS gains from the current stake
        uint STLOSGain = _getPendingSTLOSGain(_user);
        
        _updateUserSnapshots(_user);

        if (_BATamount > 0) {
            uint BATToWithdraw = LiquityMath._min(_BATamount, currentStake);

            uint newStake = currentStake.sub(BATToWithdraw);

            // Decrease user's stake and total BAT staked
            stakes[_user] = newStake;
            totalTroveDeposits = totalTroveDeposits.sub(BATToWithdraw);
            emit TotalBATStakedUpdated(totalTroveDeposits);

            // Transfer unstaked BAT to borrowerOperations
            BATToken.transfer(borrowerOperationsAddress, BATToWithdraw);

            emit StakeChanged(_user, newStake);
        }

        emit StakingGainsWithdrawn(_user, STLOSGain);

        // Send accumulated STLOS gains to the caller
        stlosToken.transfer(_user, STLOSGain);
    }


    function increaseF_STLOS(uint _STLOSFee) external override {
        _requireCallerIsActivePool();
        uint STLOSFeePerBATStaked;
        
        if (totalTroveDeposits > 0) {STLOSFeePerBATStaked = _STLOSFee.mul(DECIMAL_PRECISION).div(totalTroveDeposits);}
        
        F_STLOS = F_STLOS.add(STLOSFeePerBATStaked);
        emit F_STLOSUpdated(F_STLOS);
    }

    function getPendingSTLOSGain(address _user) external view override returns (uint) {
        return _getPendingSTLOSGain(_user);
    }

    function _getPendingSTLOSGain(address _user) internal view returns (uint) {
        uint F_STLOS_Snapshot = snapshots[_user].F_STLOS_Snapshot;
        uint STLOSGain = stakes[_user].mul(F_STLOS.sub(F_STLOS_Snapshot)).div(DECIMAL_PRECISION);
        return STLOSGain;
    }

    // --- Internal helper functions ---

    function _updateUserSnapshots(address _user) internal {
        snapshots[_user].F_STLOS_Snapshot = F_STLOS;
        emit StakerSnapshotsUpdated(_user, F_STLOS);     
    }

    // --- 'require' functions ---

    function _requireCallerIsTroveManager() internal view {
        require(msg.sender == troveManagerAddress, "BorrowerRewards: caller is not TroveM");
    }

    function _requireCallerIsBorrowerOperations() internal view {
        require(msg.sender == borrowerOperationsAddress, "BorrowerRewards: caller is not BorrowerOps");
    }

     function _requireCallerIsActivePool() internal view {
        require(msg.sender == activePoolAddress, "BorrowerRewards: caller is not ActivePool");
    }

    function _requireUserHasStake(uint currentStake) internal pure {  
        require(currentStake > 0, 'BorrowerRewards: User must have a non-zero stake');  
    }

    function _requireNonZeroAmount(uint _amount) internal pure {
        require(_amount > 0, 'BorrowerRewards: Amount must be non-zero');
    }

    receive() external payable {
        _requireCallerIsActivePool();
    }
}

