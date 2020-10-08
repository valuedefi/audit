const {expectRevert, time} = require('@openzeppelin/test-helpers');

const ValueLiquidityToken = artifacts.require('ValueLiquidityToken');
const ValueMasterPoolTest = artifacts.require('ValueMasterPool');
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

    it('should set correct state variables', async () => {
        this.masterPool = await ValueMasterPoolTest.new(this.value.address, insuranceFund, '1000', '0', {from: alice});
        await this.value.addMinter(this.masterPool.address, {from: alice});
        const value = await this.masterPool.value();
        const insuranceFundAddr = await this.masterPool.insuranceFundAddr();
        const governance = await this.value.governance();
        assert.equal(value.valueOf(), this.value.address);
        assert.equal(insuranceFundAddr.valueOf(), insuranceFund);
        assert.equal(governance.valueOf(), alice);
    });

    it('should allow insuranceFund and only insuranceFund to update insuranceFund', async () => {
        this.masterPool = await ValueMasterPoolTest.new(this.value.address, insuranceFund, '1000', '0', {from: alice});
        assert.equal((await this.masterPool.insuranceFundAddr()).valueOf(), insuranceFund);
        await expectRevert(this.masterPool.setInsuranceFundAddr(bob, { from: bob }), 'insuranceFund: wut?');
        await this.masterPool.setInsuranceFundAddr(bob, { from: insuranceFund });
        assert.equal((await this.masterPool.insuranceFundAddr()).valueOf(), bob);
        await this.masterPool.setInsuranceFundAddr(alice, { from: bob });
        assert.equal((await this.masterPool.insuranceFundAddr()).valueOf(), alice);
    })

    it('test should give out VALUEs only after farming time', async () => {
        this.masterPool = await ValueMasterPoolTest.new(this.value.address, insuranceFund, '10', '50', {from: alice});
        this.ref = await YFVReferral.new({from: alice});
        await this.ref.setAdminStatus(this.masterPool.address, true, {from: alice});
        await this.masterPool.setRewardReferral(this.ref.address, {from: alice});
        console.log('startBlock=%s', String(await this.masterPool.startBlock().valueOf()));
        console.log('valuePerBlock=%s', String(await this.masterPool.valuePerBlock().valueOf()));
        console.log('totalSupply(VALUE)=%s', String(await this.value.totalSupply().valueOf()));
        await this.value.addMinter(this.masterPool.address, {from: alice});
        this.lp = await MockERC20.new('LPToken', 'LP', '10000000000', {from: minter});
        await this.lp.transfer(alice, '1000', {from: minter});
        await this.lp.transfer(bob, '1000', {from: minter});
        await this.lp.transfer(carol, '1000', {from: minter});
        await this.masterPool.add('100', this.lp.address, true, 0);
        // console.log('init: pool(0)=%s', JSON.stringify(await this.masterPool.poolInfo(0)));
        await this.lp.approve(this.masterPool.address, '1000', {from: bob});
        await this.lp.approve(this.masterPool.address, '1000', {from: carol});
        await this.masterPool.deposit(0, '100', carol, {from: bob});
        // console.log('bob deposit: pool(0)=%s', JSON.stringify(await this.masterPool.poolInfo(0)));
        await expectRevert(
            this.masterPool.deposit(0, '100', carol, {from: carol}),
            'You cannot refer yourself',
        );
        // await this.masterPool.deposit(0, '100', ADDRESS_ZERO, {from: carol});
        // console.log('carol deposit: pool(0)=%s', JSON.stringify(await this.masterPool.poolInfo(0)));
        assert.equal((await this.value.balanceOf(bob)).valueOf(), '0');
        assert.equal((await this.value.balanceOf(carol)).valueOf(), '0');

        for (let i = 0; i < 5; i++) {
            console.log('block: %d', 50 + i * 10);
            await time.advanceBlockTo(50 + i * 10);
            await this.masterPool.deposit(0, '0', ADDRESS_ZERO, {from: bob});
            // await this.masterPool.deposit(0, '0', ADDRESS_ZERO, {from: carol});
            console.log('--> balanceOf(bob)=%s', String(await this.value.balanceOf(bob)).valueOf());
            console.log('--> balanceOf(carol)=%s', String(await this.value.balanceOf(carol)).valueOf());
            console.log('--> balanceOf(insuranceFund)=%s', String(await this.value.balanceOf(insuranceFund)).valueOf());
            console.log('--> totalSupply(VALUE)=%s', String(await this.value.totalSupply().valueOf()));
        }
    });

    it('test should update totalAllocPoint only after pool started', async () => {
        this.masterPool = await ValueMasterPoolTest.new(this.value.address, insuranceFund, '1', '300', {from: alice});
        this.ref = await YFVReferral.new({from: alice});
        await this.ref.setAdminStatus(this.masterPool.address, true, {from: alice});
        await this.masterPool.setRewardReferral(this.ref.address, {from: alice});
        await this.value.addMinter(this.masterPool.address, {from: alice});
        this.lp = await MockERC20.new('LPToken', 'LP', '10000000000', {from: minter});
        await this.lp.transfer(alice, '1000', {from: minter});
        await this.lp.transfer(bob, '1000', {from: minter});
        await this.lp.transfer(carol, '1000', {from: minter});
        await this.lp.approve(this.masterPool.address, '1000', {from: bob});
        await this.lp.approve(this.masterPool.address, '1000', {from: carol});
        this.lp2 = await MockERC20.new('LPToken2', 'LP2', '10000000000', {from: minter});
        await this.lp2.transfer(alice, '1000', {from: minter});
        await this.lp2.transfer(bob, '1000', {from: minter});
        await this.lp2.transfer(carol, '1000', {from: minter});
        await this.lp2.approve(this.masterPool.address, '1000', {from: bob});
        await this.lp2.approve(this.masterPool.address, '1000', {from: carol});
        this.lp3 = await MockERC20.new('LPToken3', 'LP3', '10000000000', {from: minter});
        await this.lp3.transfer(alice, '1000', {from: minter});
        await this.lp3.transfer(bob, '1000', {from: minter});
        await this.lp3.transfer(carol, '1000', {from: minter});
        await this.lp3.approve(this.masterPool.address, '1000', {from: bob});
        await this.lp3.approve(this.masterPool.address, '1000', {from: carol});
        await this.masterPool.add('100', this.lp.address, true, 200);
        await this.masterPool.add('100', this.lp2.address, true, 400);
        await this.masterPool.deposit(0, '100', carol, {from: bob});
        await this.masterPool.deposit(1, '100', ADDRESS_ZERO, {from: carol});
        assert.equal((await this.value.balanceOf(bob)).valueOf(), '0');
        assert.equal((await this.value.balanceOf(carol)).valueOf(), '0');
        for (let i = 1; i <= 15; i++) {
            console.log('block: %d', 100 + i * 50);
            await time.advanceBlockTo(100 + i * 50);
            console.log('--> stakingPower(0, bob)=%s', String(await this.masterPool.stakingPower(0, bob)).valueOf());
            console.log('--> stakingPower(1, carol)=%s', String(await this.masterPool.stakingPower(1, carol)).valueOf());
            await this.masterPool.deposit(0, '0', ADDRESS_ZERO, {from: bob});
            await this.masterPool.deposit(1, '0', ADDRESS_ZERO, {from: carol});
            if (i == 4) {
                // update pool
                console.log('--> UPDATE POOL 2');
                await this.masterPool.set(1, '50', true);
            }
            if (i == 5) {
                // open another late pool
                console.log('--> OPEN POOL 3');
                await this.masterPool.add('1000', this.lp3.address, true, 450);
                await this.masterPool.deposit(2, '100', ADDRESS_ZERO, {from: carol});
                console.log('--> UPDATE POOL 1');
                await this.masterPool.set(0, '0', true);
            }
            if (i > 5) await this.masterPool.deposit(2, '0', ADDRESS_ZERO, {from: carol});
            console.log('--> totalAllocPoint=%s', String(await this.masterPool.totalAllocPoint()).valueOf());
            // console.log('--> pool[0]=%s', JSON.stringify(await this.masterPool.poolInfo(0)));
            // console.log('--> pool[1]=%s', JSON.stringify(await this.masterPool.poolInfo(1)));
            console.log('--> balanceOf(bob)=%s', String(await this.value.balanceOf(bob)).valueOf());
            console.log('--> balanceOf(carol)=%s', String(await this.value.balanceOf(carol)).valueOf());
            console.log('--> balanceOf(insuranceFund)=%s', String(await this.value.balanceOf(insuranceFund)).valueOf());
            console.log('--> totalSupply(VALUE)=%s', String(await this.value.totalSupply().valueOf()));
        }
    });
});
