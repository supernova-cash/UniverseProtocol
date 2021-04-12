pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '../lib/UniswapV2Library.sol';
import '../interfaces/IUniswapV2Pair.sol';

//取交易对中两种币的平均量  
contract MockLiquidityOracle {
    using SafeMath for uint256;

    address public token0;
    address public token1;
    IUniswapV2Pair public pair;

    address public usdt;

    uint256 public blockTimestampLast;
    uint256 public reserve0Average;
    uint256 public reserve1Average;

    IUniswapV2Pair public token0UsdtPair;
    IUniswapV2Pair public token1UsdtPair;

    constructor(
        address _factory,
        address _tokenA,
        address _tokenB,
        address _usdt
    ) public {
        usdt = _usdt;
    }

    function update() external {
        blockTimestampLast = block.timestamp;
    }

    function consult(address token)
        public
        view
        returns (uint256)
    {
        return 10 ** 18 * 500000;
    }

    function tvl()
        external
        view
        returns (uint256)
    {
        return consult(token0).add(consult(token1));
    }
}