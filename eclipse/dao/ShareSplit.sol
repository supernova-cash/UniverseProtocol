pragma solidity ^0.6.0;
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../Share.sol";
import "../owner/AdminRole.sol";

contract ShareSplit is AdminRole{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public share;
    address public sShare;
    address public vShare;
    address public fund;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _sShareRewards;
    mapping(address => uint256) private _vShareRewards;

    uint256 public voteStats = 0;

    constructor(
        address share_,
        address sShare_,
        address vShare_,
        address fund_
    ) public {
        share = share_;
        sShare = sShare_;
        vShare = vShare_;
        fund = fund_;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        IERC20(share).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public {
        require(amount > 0, "Cannot withdraw 0");
        require(amount <= _balances[msg.sender], "Cannot withdraw");

        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        IERC20(share).safeTransfer(msg.sender, amount);
    }

    function split() public {
        uint256 amount = balanceOf(msg.sender);
        require(amount > 0, "Cannot split 0");

        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = 0;

        IERC20(share).safeTransfer(fund, amount);

        _vShareRewards[msg.sender] = _vShareRewards[msg.sender].add(amount);
        _sShareRewards[msg.sender] = _sShareRewards[msg.sender].add(amount);

        SShare(sShare).mint(address(this), amount);
        VShare(vShare).mint(address(this), amount);
    }

    function earnedV(address account) public view returns (uint256) {
        return _vShareRewards[account];
    }

    function earnedS(address account) public view returns (uint256) {
        return _sShareRewards[account];
    }

    function getRewardV() public {
        require(voteStats == 0, "Cannot withdraw when voting");

        uint256 reward = _vShareRewards[msg.sender];
        require(reward > 0, "Cannot getRewardV 0");

        _vShareRewards[msg.sender] = 0;
        IERC20(vShare).safeTransfer(msg.sender, reward);
    }

    function getRewardS() public {
        uint256 reward = _sShareRewards[msg.sender];
        require(reward > 0, "Cannot getRewardS 0");

        _sShareRewards[msg.sender] = 0;
        IERC20(sShare).safeTransfer(msg.sender, reward);
    }

    function stakeV(uint256 amount) public {
        _vShareRewards[msg.sender] = _vShareRewards[msg.sender].add(amount);
        IERC20(vShare).safeTransferFrom(msg.sender, address(this), amount);
    }

    function setVoteStats(uint8 voteStats_) public onlyAdmin {
        voteStats = voteStats_;
    }
}
