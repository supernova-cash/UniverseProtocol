pragma solidity ^0.6.0;
//pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./lib/Safe112.sol";
import "./owner/AdminRole.sol";
import "./utils/ContractGuard.sol";
import "./interfaces/ISuperNovaAsset.sol";

contract SHAREWrapper2 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public share0;
    IERC20 public share1;

    uint256 private _totalSupply0;
    uint256 private _totalSupply1;
    mapping(address => uint256) private _balances0;
    mapping(address => uint256) private _balances1;

    function totalSupply() public view returns (uint256) {
        return _totalSupply0.add(_totalSupply1);
    }

    function totalSupply0() public view returns (uint256) {
        return _totalSupply0;
    }

    function totalSupply1() public view returns (uint256) {
        return _totalSupply1;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances0[account].add(_balances1[account]);
    }

    function balanceOf0(address account) public view returns (uint256) {
        return _balances0[account];
    }

    function balanceOf1(address account) public view returns (uint256) {
        return _balances1[account];
    }

    function stake0(uint256 amount) public virtual {
        _totalSupply0 = _totalSupply0.add(amount);
        _balances0[msg.sender] = _balances0[msg.sender].add(amount);
        share0.safeTransferFrom(msg.sender, address(this), amount);
    }

    function stake1(uint256 amount) public virtual {
        _totalSupply1 = _totalSupply1.add(amount);
        _balances1[msg.sender] = _balances1[msg.sender].add(amount);
        share1.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw0(uint256 amount) public virtual {
        uint256 directorLPT0 = _balances0[msg.sender];
        require(
            directorLPT0 >= amount,
            "Expansion: withdraw request greater than staked amount"
        );
        _totalSupply0 = _totalSupply0.sub(amount);
        _balances0[msg.sender] = directorLPT0.sub(amount);
        share0.safeTransfer(msg.sender, amount);
    }

    function withdraw1(uint256 amount) public virtual {
        uint256 directorLPT1 = _balances1[msg.sender];
        require(
            directorLPT1 >= amount,
            "Expansion: withdraw request greater than staked amount"
        );
        _totalSupply1 = _totalSupply1.sub(amount);
        _balances1[msg.sender] = directorLPT1.sub(amount);
        share1.safeTransfer(msg.sender, amount);
    }
}

contract ShareBoardroom2 is SHAREWrapper2, ContractGuard, AdminRole {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using Safe112 for uint112;

    /* ========== DATA STRUCTURES ========== */

    struct Boardseat {
        uint256 lastSnapshotIndex;
        uint256 rewardEarned;
    }

    struct BoardSnapshot {
        uint256 time;
        uint256 rewardReceived;
        uint256 rewardPerLPT;
    }

    /* ========== STATE VARIABLES ========== */

    IERC20 public cash;

    mapping(address => Boardseat) private directors;
    BoardSnapshot[] private boardHistory;

    mapping(address => uint256) private lastStakeTime;

    /* ========== CONSTRUCTOR ========== */

    constructor(IERC20 _cash, IERC20 _share0, IERC20 _share1) public {
        cash = _cash;
        share0 = _share0;
        share1 = _share1;

        BoardSnapshot memory genesisSnapshot =
            BoardSnapshot({
                time: block.number,
                rewardReceived: 0,
                rewardPerLPT: 0
            });
        boardHistory.push(genesisSnapshot);
    }

    /* ========== Modifiers =============== */
    modifier directorExists {
        require(
            balanceOf(msg.sender) > 0,
            "Expansion: The director does not exist"
        );
        _;
    }

    modifier updateReward(address director) {
        if (director != address(0)) {
            Boardseat memory seat = directors[director];
            seat.rewardEarned = earned(director);
            seat.lastSnapshotIndex = latestSnapshotIndex();
            directors[director] = seat;
        }
        _;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function getLastStakeTime() public view returns (uint256) {
        return lastStakeTime[msg.sender];
    }

    // =========== Snapshot getters

    function latestSnapshotIndex() public view returns (uint256) {
        return boardHistory.length.sub(1);
    }

    function getLatestSnapshot() internal view returns (BoardSnapshot memory) {
        return boardHistory[latestSnapshotIndex()];
    }

    function getLastSnapshotIndexOf(address director)
        public
        view
        returns (uint256)
    {
        return directors[director].lastSnapshotIndex;
    }

    function getLastSnapshotOf(address director)
        internal
        view
        returns (BoardSnapshot memory)
    {
        return boardHistory[getLastSnapshotIndexOf(director)];
    }

    // =========== Director getters

    function rewardPerLPT() public view returns (uint256) {
        return getLatestSnapshot().rewardPerLPT;
    }

    function earned(address director) public view returns (uint256) {
        uint256 latestRPS = getLatestSnapshot().rewardPerLPT;
        uint256 storedRPS = getLastSnapshotOf(director).rewardPerLPT;

        return
            balanceOf(director).mul(latestRPS.sub(storedRPS)).div(1e18).add(
                directors[director].rewardEarned
            );
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake0(uint256 amount)
        public
        override
        onlyOneBlock
        updateReward(msg.sender)
    {
        require(amount > 0, "Expansion: Cannot stake 0");
        super.stake0(amount);
        emit Staked(msg.sender, amount);
        lastStakeTime[msg.sender] = block.timestamp;
    }

    function stake1(uint256 amount)
        public
        override
        onlyOneBlock
        updateReward(msg.sender)
    {
        require(amount > 0, "Expansion: Cannot stake 0");
        super.stake1(amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw0(uint256 amount)
        public
        override
        onlyOneBlock
        directorExists
        updateReward(msg.sender)
    {
        require(amount > 0, "Expansion: Cannot withdraw 0");
        require(
            lastStakeTime[msg.sender] + 259200 < block.timestamp,
            "Expansion: Cannot withdraw in three ERA"
        );
        super.withdraw0(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function withdraw1(uint256 amount)
        public
        override
        onlyOneBlock
        directorExists
        updateReward(msg.sender)
    {
        require(0 > 1, "Cannot withdraw sSHARE");
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw0(balanceOf0(msg.sender));
        claimReward();
    }

    function claimReward() public updateReward(msg.sender) {
        uint256 reward = directors[msg.sender].rewardEarned;
        if (reward > 0) {
            directors[msg.sender].rewardEarned = 0;
            cash.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function allocateSeigniorage(uint256 amount)
        external
        onlyOneBlock
        onlyAdmin
    {
        require(amount > 0, "Expansion: Cannot allocate 0");
        require(
            totalSupply() > 0,
            "Expansion: Cannot allocate when totalSupply is 0"
        );

        // Create & add new snapshot
        uint256 prevRPS = getLatestSnapshot().rewardPerLPT;
        uint256 nextRPS = prevRPS.add(amount.mul(1e18).div(totalSupply()));

        BoardSnapshot memory newSnapshot =
            BoardSnapshot({
                time: block.number,
                rewardReceived: amount,
                rewardPerLPT: nextRPS
            });
        boardHistory.push(newSnapshot);

        cash.safeTransferFrom(msg.sender, address(this), amount);
        emit RewardAdded(msg.sender, amount);
    }

    /* ========== EVENTS ========== */

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(address indexed user, uint256 reward);
}
