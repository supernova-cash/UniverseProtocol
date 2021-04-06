pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import './lib/UniswapV2Library.sol';
import './interfaces/IUniswapV2Pair.sol';

//取交易对中两种币的平均量  
contract LiquidityOracle {
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
        pair = IUniswapV2Pair(UniswapV2Library.pairFor(_factory, _tokenA, _tokenB));
        token0 = pair.token0();
        token1 = pair.token1();
        (reserve0Average, reserve1Average, blockTimestampLast) = pair.getReserves();

        token0UsdtPair = IUniswapV2Pair(UniswapV2Library.pairFor(_factory, token0, usdt));
        token1UsdtPair = IUniswapV2Pair(UniswapV2Library.pairFor(_factory, token1, usdt));
    }

    function update() external {
        (
            uint256 reserve0,
            uint256 reserve1,
            uint32 _
        ) = pair.getReserves();

        uint256 timeElapsed = block.timestamp - blockTimestampLast;

        if (timeElapsed == 0) {
            return;
        }

        if (timeElapsed > 3600) {
            timeElapsed = 3600;
        }

        reserve0Average = reserve0Average.mul(3600 - timeElapsed).add(reserve0.mul(timeElapsed)).div(3600);
        reserve1Average = reserve1Average.mul(3600 - timeElapsed).add(reserve1.mul(timeElapsed)).div(3600);

        blockTimestampLast = block.timestamp;
    }

    function consult(address token)
        public
        view
        returns (uint256)
    {
        if (token == token0) {
            (
                uint256 reserve0,
                uint256 reserve1,
                uint32 _
            ) = token0UsdtPair.getReserves();

            if(usdt == token0UsdtPair.token0()){
                return reserve0Average.mul(reserve0).div(reserve1);
            }
            return reserve0Average.mul(reserve1).div(reserve0);
        }

        if (token == token1){
            (
                uint256 reserve0,
                uint256 reserve1,
                uint32 _
            ) = token1UsdtPair.getReserves();

            if(usdt == token1UsdtPair.token0()){
                return reserve1Average.mul(reserve0).div(reserve1);
            }
            return reserve1Average.mul(reserve1).div(reserve0);
        }

        return 0;
    }

    function tvl()
        external
        view
        returns (uint256)
    {
        return consult(token0).add(consult(token1));
    }
}