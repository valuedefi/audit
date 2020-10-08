const {expectRevert, ether} = require('@openzeppelin/test-helpers');
const ValueLiquidityToken = artifacts.require('ValueLiquidityToken');
const MockERC20 = artifacts.require('MockERC20');

contract('ValueLiquidityToken', ([alice, bob, carol]) => {
    beforeEach(async () => {
        this.yfv = await MockERC20.new('YFValue', 'YFV', ether('4000000'), {from: alice});
        this.value = await ValueLiquidityToken.new(this.yfv.address, ether('2370000'), {from: alice});
    });

    it('should have correct name and symbol and decimal', async () => {
        const name = await this.value.name();
        const symbol = await this.value.symbol();
        const decimals = await this.value.decimals();
        assert.equal(name.valueOf(), 'Value Liquidity');
        assert.equal(symbol.valueOf(), 'VALUE');
        assert.equal(decimals.valueOf(), '18');
    });

    it('should only allow minters to mint token', async () => {
        await this.value.mint(alice, ether('100'), {from: alice});
        await this.value.addMinter(bob, {from: alice});
        await this.value.mint(carol, ether('1000'), {from: bob});
        await this.value.removeMinter(bob, {from: alice});
        await expectRevert(
            this.value.mint(carol, ether('1000'), {from: bob}),
            '!governance && !minter',
        );
        const totalSupply = await this.value.totalSupply();
        const aliceBal = await this.value.balanceOf(alice);
        const bobBal = await this.value.balanceOf(bob);
        const carolBal = await this.value.balanceOf(carol);
        assert.equal(totalSupply.valueOf(), String(ether('1100')));
        assert.equal(aliceBal.valueOf(), String(ether('100')));
        assert.equal(bobBal.valueOf(), '0');
        assert.equal(carolBal.valueOf(), String(ether('1000')));
    });

    it('should deposit and withdraw not over the locked yfv', async () => {
        await this.yfv.approve(this.value.address, '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', {from: alice});
        await this.value.deposit(ether('2000'), {from: alice});
        assert.equal(String(await this.yfv.balanceOf(alice)), String(ether('3998000')));
        assert.equal(String(await this.yfv.balanceOf(this.value.address)), String(ether('2000')));
        await this.yfv.transfer(bob, ether('1000'), {from: alice});
        await expectRevert(
            this.value.deposit(ether('1000'), {from: bob}),
            'ERC20: transfer amount exceeds allowance',
        );
        await this.value.mint(bob, ether('10000'), {from: alice});
        await this.value.approve(this.value.address, '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', {from: bob});
        await this.value.withdraw(ether('1000'), {from: bob});
        assert.equal(String(await this.yfv.balanceOf(bob)), String(ether('2000')));
        assert.equal(String(await this.value.balanceOf(bob)), String(ether('9000')));
        assert.equal(String(await this.yfv.balanceOf(this.value.address)), String(ether('1000')));
        await this.value.deposit(ether('9000'), {from: alice});
        await expectRevert(
            this.value.withdraw(ether('9001'), {from: bob}),
            'ERC20: burn amount exceeds balance',
        );
        await this.value.approve(this.value.address, '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', {from: alice});
        this.value.withdraw(ether('1500'), {from: alice});
        assert.equal(String(await this.value.yfvLockedBalance()), String(ether('8500')));
        await expectRevert(
            this.value.withdraw(ether('9000'), {from: bob}),
            'There is not enough locked YFV to withdraw',
        );
    });

    it('set new cap should not over totalSupply minus yfvLockedBalance', async () => {
        assert.equal(String(await this.value.cap()), String(ether('2370000')));
        await this.value.mint(bob, ether('2370000'), {from: alice});
        await expectRevert(
            this.value.mint(bob, ether('1'), {from: alice}),
            'ERC20Capped: cap exceeded',
        );
        assert.equal(String(await this.value.totalSupply()), String(ether('2370000')));
        await this.yfv.approve(this.value.address, '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', {from: alice});
        await this.value.deposit(ether('1000000'), {from: alice});
        assert.equal(String(await this.yfv.balanceOf(alice)), String(ether('3000000')));
        assert.equal(String(await this.value.balanceOf(alice)), String(ether('1000000')));
        assert.equal(String(await this.yfv.balanceOf(this.value.address)), String(ether('1000000')));
        await this.value.setCap(ether('3000000'), {from: alice});
        assert.equal(String(await this.value.cap()), String(ether('3000000')));
        await this.value.mint(bob, ether('630000'), {from: alice});
        assert.equal(String(await this.value.totalSupply()), String(ether('4000000')));
        await expectRevert(
            this.value.setCap(ether('2900000'), {from: alice}),
            '_cap (plus yfvLockedBalance) is below current supply',
        );
        await this.value.setCap(ether('3100000'), {from: alice});
    });

    it('should supply token transfers properly', async () => {
        await this.value.mint(alice, '100', {from: alice});
        await this.value.mint(bob, '1000', {from: alice});
        await this.value.transfer(carol, '10', {from: alice});
        await this.value.transfer(carol, '100', {from: bob});
        const totalSupply = await this.value.totalSupply();
        const aliceBal = await this.value.balanceOf(alice);
        const bobBal = await this.value.balanceOf(bob);
        const carolBal = await this.value.balanceOf(carol);
        assert.equal(totalSupply.valueOf(), '1100');
        assert.equal(aliceBal.valueOf(), '90');
        assert.equal(bobBal.valueOf(), '900');
        assert.equal(carolBal.valueOf(), '110');
    });

    it('should fail if you try to do bad transfers', async () => {
        await this.value.mint(alice, '100', {from: alice});
        await expectRevert(
            this.value.transfer(carol, '110', {from: alice}),
            'ERC20: transfer amount exceeds balance',
        );
        await expectRevert(
            this.value.transfer(carol, '1', {from: bob}),
            'ERC20: transfer amount exceeds balance',
        );
    });

    it('test governanceRecoverUnsupported', async () => {
        this.anErc20Token = await MockERC20.new('TokenA', 'A', ether('10000'), {from: bob});
        await this.anErc20Token.transfer(this.value.address, ether('1000'), {from: bob});
        assert.equal(String(await this.anErc20Token.balanceOf(bob)), String(ether('9000')));
        assert.equal(String(await this.anErc20Token.balanceOf(this.value.address)), String(ether('1000')));
        await this.value.governanceRecoverUnsupported(this.anErc20Token.address, carol, ether('1000'));
        assert.equal(String(await this.anErc20Token.balanceOf(carol)), String(ether('1000')));
        assert.equal(String(await this.anErc20Token.balanceOf(this.value.address)), String(ether('0')));
        await this.yfv.approve(this.value.address, '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', {from: alice});
        await this.value.deposit(ether('1000'), {from: alice});
        assert.equal(String(await this.yfv.balanceOf(this.value.address)), String(ether('1000')));
        await expectRevert(
            this.value.governanceRecoverUnsupported(this.yfv.address, carol, ether('1000'), {from: alice}),
            'cant withdraw more then stuck amount',
        );
        await this.yfv.transfer(this.value.address, ether('1000'), {from: alice});
        assert.equal(String(await this.yfv.balanceOf(this.value.address)), String(ether('2000')));
        await this.value.governanceRecoverUnsupported(this.yfv.address, carol, ether('1000'), {from: alice});
        assert.equal(String(await this.yfv.balanceOf(carol)), String(ether('1000')));
    });
});
