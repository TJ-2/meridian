// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../Dependencies/IERC20.sol";

interface IBorrowerAccountingToken is IERC20 { 

    // --- Functions ---

    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;

}
