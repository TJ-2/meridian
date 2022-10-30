// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../LQTY/CommunityIssuance.sol";

contract CommunityIssuanceTester is CommunityIssuance {
    function obtainLQTY(uint _amount) external {
        lqtyToken.transfer(msg.sender, _amount);
    }

}
