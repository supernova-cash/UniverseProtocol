pragma solidity ^0.6.0;

contract MockOracle {
    address  public factory;
    address public token0;
    address public token1;
    uint256 public period;
    uint256 public startTime;
    uint256 public price = 10 ** 18;

    constructor(
        address _factory,
        address _tokenA,
        address _tokenB,
        uint256 _period,
        uint256 _startTime
    ) public {
        factory =  _factory;
        token0 = _tokenA;
        token1 = _tokenB;
        period = _period;
        startTime = _startTime;
       
    }

    function update() external {      
        startTime = 0;
    }

    function updatePrice(uint256 price_) external {      
        price = price_;
    }

    function consult(address token, uint256 amountIn)
        external
        view
        returns (uint256)
    {
        return price;
    }

    function expectedPrice(address token, uint256 amountIn)
        external
        view
        returns (uint256)
    {
        return price;
    }
}