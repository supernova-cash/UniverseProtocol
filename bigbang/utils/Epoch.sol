pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

import '../owner/AdminRole.sol';

contract Epoch is AdminRole {
    using SafeMath for uint256;

    uint256 private period;
    uint256 private startTime;
    uint256 private epoch;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        uint256 _period,
        uint256 _startTime,
        uint256 _startEpoch
    ) public {
        period = _period;
        startTime = _startTime;
        epoch = _startEpoch;
    }

    /* ========== Modifier ========== */

    modifier checkStartTime {
        require(now >= startTime, 'Epoch: not started yet');

        _;
    }

    modifier checkEpoch {
        require(now >= nextEpochPoint(), 'Epoch: not allowed');

        _;

        epoch = epoch.add(1);
    }

    /* ========== VIEW FUNCTIONS ========== */

    function getCurrentEpoch() external view returns (uint256) {
        return epoch;
    }

    function getPeriod() external view returns (uint256) {
        return period;
    }

    function getStartTime() external view returns (uint256) {
        return startTime;
    }

    function nextEpochPoint() public view returns (uint256) {
        return startTime.add(epoch.mul(period));
    }

    /* ========== GOVERNANCE ========== */

    function setPeriod(uint256 _period) external onlyAdmin {
        period = _period;
        emit SetPeriod(_period);
    }

    event SetPeriod(uint256 period);
}
