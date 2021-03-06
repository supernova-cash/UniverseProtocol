pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/IOracle.sol";
import "./interfaces/IBoardroom.sol";
import "./interfaces/ISuperNovaAsset.sol";
import "./interfaces/ISimpleERCFund.sol";
import "./lib/Babylonian.sol";
import "./lib/FixedPoint.sol";
import "./lib/Safe112.sol";
import "./owner/AdminRole.sol";
import "./utils/Epoch.sol";
import "./utils/ContractGuard.sol";
import "./Fund.sol";
import "./pool/CashPool.sol";
import "./pool/SharePool.sol";
import "./pool/PegPool.sol";

contract Treasury2 is ContractGuard, Epoch {
    using FixedPoint for *;
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using Safe112 for uint112;

    /* ========== STATE VARIABLES ========== */

    // ========== FLAGS
    bool public migrated = false;

    // ========== CORE
    address public fund;
    address public cash;
    address public share;
    address public peg;
    address public shareboardroom;
    address public lpboardroom;
    address public sharePool;
    address public cashPool;
    address public pegPool;
    uint256 public sharePoolLastAmount = 0;
    uint256 public cashPoolLastAmount = 0;
    uint256 public pegPoolLastAmount = 0;

    address public oracle;

    // ========== PARAMS
    uint256 public cashPriceOne;
    uint256 public cashPriceCeiling;
    uint256 public cashPriceFloor;
    uint256 public fundAllocationRate = 5;
    uint256 public inflationPercentCeil;
    uint256 public initShare;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _cash,
        address _share,
        address _peg,
        address _oracle,
        address _shareboardroom,
        address _lpboardroom,
        address _fund,
        address _cashPool,
        address _sharePool,
        address _pegPool,
        uint256 _initShare,
        uint256 _startTime
    ) public Epoch(1 days, _startTime, 0) {
        require(_cash != address(0), "Treasury2: the zero address");
        require(_share != address(0), "Treasury2: the zero address");
        require(_peg != address(0), "Treasury2: the zero address");
        require(_oracle != address(0), "Treasury2: the zero address");
        require(_shareboardroom != address(0), "Treasury2: the zero address");
        require(_lpboardroom != address(0), "Treasury2: the zero address");
        require(_fund != address(0), "Treasury2: the zero address");
        require(_cashPool != address(0), "Treasury2: the zero address");
        require(_sharePool != address(0), "Treasury2: the zero address");
        require(_pegPool != address(0), "Treasury2: the zero address");
        cash = _cash;
        share = _share;
        peg = _peg;
        oracle = _oracle;
        shareboardroom = _shareboardroom;
        lpboardroom = _lpboardroom;
        fund = _fund;
        cashPool = _cashPool;
        sharePool = _sharePool;
        pegPool = _pegPool;
        initShare = _initShare;

        cashPriceOne = 10**18;
        // cashPriceOne = 10**8;
        cashPriceCeiling = uint256(105).mul(cashPriceOne).div(10**2);
        cashPriceFloor = uint256(95).mul(cashPriceOne).div(10**2);
        // inflation at most 100%
        inflationPercentCeil = uint256(100).mul(cashPriceOne).div(10**2);
    }

    /* =================== Modifier =================== */

    modifier checkMigration {
        require(!migrated, "Treasury: migrated");

        _;
    }

    modifier checkAdmin {
        require(
            AdminRole(cash).isAdmin(address(this)) &&
                AdminRole(share).isAdmin(address(this)) &&
                AdminRole(shareboardroom).isAdmin(address(this)) &&
                AdminRole(lpboardroom).isAdmin(address(this)),
            "Treasury: need more permission"
        );

        _;
    }

    /* ========== VIEW FUNCTIONS ========== */

    // budget
    function getReserve() public view returns (uint256) {
        return 0;
    }

    // oracle
    function getSeigniorageOraclePrice() public view returns (uint256) {
        return _getCashPrice(oracle);
    }

    function _getCashPrice(address oracle_) internal view returns (uint256) {
        try IOracle(oracle_).consult(cash, 1e18) returns (uint256 price) {
            return price.mul(cashPriceOne).div(cashPriceOne);
        } catch {
            revert("Treasury: failed to consult cash price from the oracle");
        }
    }

    function migrate(address target) public onlyAdmin checkAdmin {
        require(!migrated, "Treasury: migrated");

        migrated = true;

        // cash
        AdminRole(cash).addAdmin(target);
        AdminRole(cash).renounceAdmin();
        IERC20(cash).transfer(target, IERC20(cash).balanceOf(address(this)));

        // share
        AdminRole(share).addAdmin(target);
        AdminRole(share).renounceAdmin();
        IERC20(share).transfer(target, IERC20(share).balanceOf(address(this)));

        // peg
        IERC20(peg).transfer(target, IERC20(peg).balanceOf(address(this)));

        emit Migration(target);
    }

    function setInitShare(uint256 initShare_) public onlyAdmin {
        initShare = initShare_;
        emit SetInitShare(initShare_);
    }

    function setFund(address newFund) public onlyAdmin {
        require(newFund != address(0), "setFund: the zero address");
        fund = newFund;
        emit SetFund(newFund);
    }

    function setFundAllocationRate(uint256 rate) public onlyAdmin {
        fundAllocationRate = rate;
        emit SetFundAllocationRate(rate);
    }

    /* ========== MUTABLE FUNCTIONS ========== */

    function _updateCashPrice() internal {
        try IOracle(oracle).update() {} catch {}
    }

    function allocateSeigniorage()
        external
        //????????????????????????
        onlyOneBlock
        checkMigration
        checkStartTime
        checkEpoch
        checkAdmin
    {
        //release
        if (cashPoolLastAmount > 0) {
            CashPool(cashPool).release(cashPoolLastAmount);
            cashPoolLastAmount = 0;
        }
        if (sharePoolLastAmount > 0) {
            SharePool(sharePool).release(sharePoolLastAmount);
            sharePoolLastAmount = 0;
        }
        if (pegPoolLastAmount > 0) {
            PegPool(pegPool).release(pegPoolLastAmount);
            pegPoolLastAmount = 0;
        }

        //fund?????????cash????????????
        uint256 burnAmount = IERC20(cash).balanceOf(fund);
        if (burnAmount > 0) {
            ISimpleERCFund(fund).withdraw(
                cash,
                burnAmount,
                address(this),
                "burn cash"
            );
            ISuperNovaAsset(cash).burn(burnAmount);
            emit BurnCash(now, burnAmount);
        }

        _updateCashPrice();
        uint256 cashPrice = _getCashPrice(oracle);
        uint256 percentage =
            cashPriceOne > cashPrice
                ? cashPriceOne.sub(cashPrice)
                : cashPrice.sub(cashPriceOne);
        //?????????<0.95???
        if (cashPrice <= cashPriceFloor) {
            // ??????share ????????????cash???share
            uint256 shareAmount = initShare.div(10**2);
            ISuperNovaAsset(share).mint(sharePool, shareAmount);
            emit MintSharePool(block.timestamp, shareAmount);
            sharePoolLastAmount = shareAmount;

            // ???fund?????????peg ??????cash
            uint256 pegAmount =
                IERC20(peg).balanceOf(fund).mul(percentage).div(cashPriceOne);
            ISimpleERCFund(fund).withdraw(
                peg,
                pegAmount,
                pegPool,
                "Treasury: Desposit PegPool"
            );
            emit DespositPegPool(now, pegAmount);
            pegPoolLastAmount = pegAmount;
        }

        if (cashPrice <= cashPriceCeiling) {
            return; // just advance epoch instead revert
        }

        // circulating supply
        uint256 cashSupply = IERC20(cash).totalSupply();

        percentage = Math.min(percentage, inflationPercentCeil);

        uint256 seigniorage = cashSupply.mul(percentage).div(10**18);

        uint256 fundReserve = seigniorage.mul(fundAllocationRate).div(100);

        ISuperNovaAsset(cash).mint(address(this), seigniorage);

        if (fundReserve > 0) {
            IERC20(cash).safeTransfer(cashPool, fundReserve);
            emit DespositCashPool(now, fundReserve);
            cashPoolLastAmount = fundReserve;
        }

        // boardroom
        uint256 boardroomReserve = seigniorage.sub(fundReserve);
        if (boardroomReserve > 0) {
            // share???????????????10%
            uint256 shareBoardroomReserve = boardroomReserve.div(10);
            // lp???????????????90%
            uint256 lpBoardroomReserve =
                boardroomReserve.sub(shareBoardroomReserve);
            // ?????????????????????????????????
            IERC20(cash).safeApprove(shareboardroom, shareBoardroomReserve);
            //??????Boardroom?????????allocateSeigniorage??????,???CASH???????????????
            IBoardroom(shareboardroom).allocateSeigniorage(
                shareBoardroomReserve
            );

            // ?????????????????????????????????
            IERC20(cash).safeApprove(lpboardroom, lpBoardroomReserve);
            //??????Boardroom?????????allocateSeigniorage??????,???CASH???????????????
            IBoardroom(lpboardroom).allocateSeigniorage(lpBoardroomReserve);
            //???????????????????????????????????????
            emit BoardroomFunded(now, boardroomReserve);
        }
    }

    // GOV
    event Migration(address indexed target);
    event ContributionPoolChanged(address indexed operator, address newFund);
    event ContributionPoolRateChanged(
        address indexed operator,
        uint256 newRate
    );

    // CORE
    event BoardroomFunded(uint256 timestamp, uint256 seigniorage);
    event BurnCash(uint256 timestamp, uint256 seigniorage);
    event MintSharePool(uint256 timestamp, uint256 seigniorage);
    event DespositPegPool(uint256 timestamp, uint256 seigniorage);
    event DespositCashPool(uint256 timestamp, uint256 seigniorage);
    event SharePoolFunded(uint256 timestamp, uint256 seigniorage);
    event CashPoolFunded(uint256 timestamp, uint256 seigniorage);
    event PegPoolFunded(uint256 timestamp, uint256 seigniorage);
    event SetInitShare(uint256 initShare);
    event SetFund(address newFund);
    event SetFundAllocationRate(uint256 rate);
}
