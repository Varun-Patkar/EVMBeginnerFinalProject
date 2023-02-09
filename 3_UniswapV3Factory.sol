// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import './interfaces/IUniswapV3Factory.sol';//SHOWING ERROR BECAUSE I HAVEN'T DOWNLOADED THE OTHER FILES

import './UniswapV3PoolDeployer.sol';
import './NoDelegateCall.sol';

import './UniswapV3Pool.sol';

/// @title Canonical Uniswap V3 factory
/// @notice Deploys Uniswap V3 pools and manages ownership and control over pool protocol fees
contract UniswapV3Factory is IUniswapV3Factory, UniswapV3PoolDeployer, NoDelegateCall {
    //INHERITS ALL THE IMPORTED CONTRACTS TO GET ALL EXTERNAL, PUBLIC, AND INTERNAL FUNCTIONS

    /// @inheritdoc IUniswapV3Factory
    address public override owner;

    /// @inheritdoc IUniswapV3Factory
    mapping(uint24 => int24) public override feeAmountTickSpacing;
    /// @inheritdoc IUniswapV3Factory
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPool;//NESTED MAPPING

    constructor() {//CALLED ON DEPLOYMENT
        owner = msg.sender;//SET OWNER TO THE PERSON WHO DEPLOYED THE CONTRACT
        emit OwnerChanged(address(0), msg.sender);//EMIT OWNERCHANGED EVENT SPECIFIED IN ./interfaces/IUniswapV3Factory.sol

        feeAmountTickSpacing[500] = 10;//SETUP THE DIFFERENT TICK SPACING VALUES FOR THE VALUES OF FEE
        emit FeeAmountEnabled(500, 10);
        feeAmountTickSpacing[3000] = 60;
        emit FeeAmountEnabled(3000, 60);
        feeAmountTickSpacing[10000] = 200;
        emit FeeAmountEnabled(10000, 200);
    }

    /// @inheritdoc IUniswapV3Factory
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override noDelegateCall returns (address pool) {
        require(tokenA != tokenB);//CHECK IF THEY'RE NOT THE SAME
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);//PUT THE SMALLER ONE IN TOKEN0 AND BIGGER IN TOKEN1
        require(token0 != address(0));//CHECK IF NOT EMPTY ADDRESS
        int24 tickSpacing = feeAmountTickSpacing[fee];//FIND THE TICK SPACING ACCORDING TO THE FEE
        require(tickSpacing != 0);//CHECK IF IT'S NOT 0
        require(getPool[token0][token1][fee] == address(0));//CHECK IF POOL IS EMPTY FOR THIS COMBINATION
        pool = deploy(address(this), token0, token1, fee, tickSpacing);//IF YES THEN DEPLOY IT USING THE GIVEN SETTINGS
        getPool[token0][token1][fee] = pool;//SET THE POOL ADDRESS IN THE MAPPING
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPool[token1][token0][fee] = pool;//SET THE SAME FOR THE REVERSE DIRECTION
        emit PoolCreated(token0, token1, fee, tickSpacing, pool);//EMIT THE EVENT
    }

    /// @inheritdoc IUniswapV3Factory
    function setOwner(address _owner) external override {//SET THE OWNER AND EMIT THE EVENT FOR IT
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /// @inheritdoc IUniswapV3Factory
    function enableFeeAmount(uint24 fee, int24 tickSpacing) public override {
        require(msg.sender == owner);//CHECK IF SENDER IS OWNER AS ONLY THEY CAN ENABLE FEE AMOUNTS
        require(fee < 1000000);//CHECK THAT FEE IS NOT TOO BIG
        // tick spacing is capped at 16384 to prevent the situation where tickSpacing is so large that
        // TickBitmap#nextInitializedTickWithinOneWord overflows int24 container from a valid tick
        // 16384 ticks represents a >5x price change with ticks of 1 bips
        require(tickSpacing > 0 && tickSpacing < 16384);//CHECK THAT TICK SPACING IS WITHIN RANGE
        require(feeAmountTickSpacing[fee] == 0);//CHECK IF THE TICK SPACING IS 0, IF NO THEN ERROR AND EXIT

        feeAmountTickSpacing[fee] = tickSpacing;//IF YES THEN SET THE APPROPRIATE TICK SPACING
        emit FeeAmountEnabled(fee, tickSpacing);//EMIT THE CORRESPONDING EVENT
    }
}