
// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

interface IStakedTLOS {
    function depositTLOS() external payable returns (uint256);
    function balanceOf(address owner) external view returns (uint);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256 );
    function transfer(address to, uint) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

} 