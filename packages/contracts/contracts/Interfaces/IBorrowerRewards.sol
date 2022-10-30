// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

interface IBorrowerRewards {

    // --- Events --
    
    event TLOSTokenAddressSet(address _tlosTokenAddress);
    event STLOSTokenAddressSet(address _stlosTokenAddress);
    event TroveManagerAddressSet(address _troveManager);
    event BorrowerOperationsAddressSet(address _borrowerOperationsAddress);
    event ActivePoolAddressSet(address _activePoolAddress);

    event StakeChanged(address indexed staker, uint newStake);
    event StakingGainsWithdrawn(address indexed staker, uint STLOSGain);
    event F_STLOSUpdated(uint _F_STLOS);
    event TotalTLOSStakedUpdated(uint _totalTLOSStaked);
    event StakerSnapshotsUpdated(address _staker, uint _F_STLOS);

    // --- Functions ---

    function setAddresses
    (
        address _tlosTokenAddress,
        address _stlosTokenAddress,
        address _troveManagerAddress, 
        address _borrowerOperationsAddress,
        address _activePoolAddress
    )  external;

    function stake(uint _TLOSamount, address _from) external;

    function unstake(uint _TLOSamount, address _from) external;

    function increaseF_STLOS(uint _TLOSFee) external;  

    function getPendingSTLOSGain(address _user) external view returns (uint);
}
