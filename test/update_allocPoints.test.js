const {expectRevert, time} = require('@openzeppelin/test-helpers');

const ValueLiquidityToken = artifacts.require('ValueLiquidityToken');
const ValueMasterPool = artifacts.require('ValueMasterPool');
const YFVReferral = artifacts.require('YFVReferral');
const MockERC20 = artifacts.require('MockERC20');

const ADDRESS_ZERO = '0x0000000000000000000000000000000000000000';

contract('ValueMasterPool', ([alice, bob, carol, insuranceFund, minter]) => {
    beforeEach(async () => {
        this.yfv = await MockERC20.new('YFValue', 'YFV', 40000000, {from: alice});
        this.value = await ValueLiquidityToken.new(this.yfv.address, 2370000, {from: alice});
        await this.yfv.approve(this.value.address, '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', {from: alice});
        await this.value.deposit(20000000, {from: alice});
    });

    it('test should update reward correctly after updating allocPoints', async () => {
        this.masterPool = await ValueMasterPool.new(this.value.address, insuranceFund, '10', '0', {from: alice});
        await this.value.addMinter(this.masterPool.address, {from: alice});
        this.lp = await MockERC20.new('LPToken', 'LP', '10000000000', {from: minter});
        this.lp2 = await MockERC20.new('LPToken2', 'LP2', '10000000000', {from: minter});
        await this.lp.transfer(alice, '1000', {from: minter});
        await this.lp.transfer(bob, '1000', {from: minter});
        await this.lp.transfer(carol, '1000', {from: minter});
        await this.lp2.transfer(alice, '1000', {from: minter});
        await this.lp2.transfer(bob, '1000', {from: minter});
        await this.lp2.transfer(carol, '1000', {from: minter});
        await this.masterPool.add('1000', this.lp.address, true, 0);
        await this.masterPool.add('1000', this.lp2.address, true, 0);
        await this.lp.approve(this.masterPool.address, '1000', {from: bob});
        await this.lp.approve(this.masterPool.address, '1000', {from: carol});
        await this.lp2.approve(this.masterPool.address, '1000', {from: bob});
        await this.lp2.approve(this.masterPool.address, '1000', {from: carol});
        await this.masterPool.deposit(0, '100', carol, {from: bob});
        await this.masterPool.deposit(0, '1', bob, {from: carol});
        await this.masterPool.deposit(1, '100', bob, {from: carol});
        for (let i = 1; i <= 5; i++) {
            await time.advanceBlock();
            console.log('latestBlock=%s', await time.latestBlock());
            console.log('--> pendingValue(0, bob)=%s', String(await this.masterPool.pendingValue(0, bob)));
            console.log('--> pendingValue(1, carol)=%s', String(await this.masterPool.pendingValue(1, carol)));
        }
        console.log('========== TURN OFF POOL 0');
        await this.masterPool.deposit(0, '0', ADDRESS_ZERO, {from: carol});
        console.log('--> pool(0)=%s', JSON.stringify(await this.masterPool.poolInfo(0)));
        await this.masterPool.set(0, '0', false);
        // await this.masterPool.setValuePerBlock(100);
        // await this.masterPool.massUpdatePools();
        console.log('--> pool(0)=%s', JSON.stringify(await this.masterPool.poolInfo(0)));
        // await this.masterPool.deposit(0, '0', ADDRESS_ZERO, {from: bob});
        // await this.masterPool.deposit(1, '0', ADDRESS_ZERO, {from: carol});
        console.log('--> balanceOf(bob)=%s', String(await this.value.balanceOf(bob)).valueOf());
        console.log('--> balanceOf(carol)=%s', String(await this.value.balanceOf(carol)).valueOf());
        for (let i = 1; i <= 5; i++) {
            await time.advanceBlock();
            console.log('latestBlock=%s', await time.latestBlock());
            console.log('--> pendingValue(0, bob)=%s', String(await this.masterPool.pendingValue(0, bob)));
            console.log('--> pendingValue(1, carol)=%s', String(await this.masterPool.pendingValue(1, carol)));
        }
        await this.masterPool.deposit(0, '0', ADDRESS_ZERO, {from: bob});
        await this.masterPool.deposit(1, '0', ADDRESS_ZERO, {from: carol});
        console.log('--> balanceOf(bob)=%s', String(await this.value.balanceOf(bob)).valueOf());
        console.log('--> balanceOf(carol)=%s', String(await this.value.balanceOf(carol)).valueOf());
    });
});
