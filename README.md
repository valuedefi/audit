# YFValue Smart-contracts
#### Bringing True Value to Yield Farming

[Full announcement](https://medium.com/@yfv.finance/yfv-bringing-true-value-to-yield-farming-bddc4edf889a)

YFV is the governance token of YFValue protocol. The project aims to bring the true value of yield farming finance accessible to all users, regardless of whether you are a big whale or small minnow, via its unique features, namely the voting of the inflationary rate of the supply and a referral system with automatic burning done fully on-chain.
- YFV.Finance is a DeFi yield aggregator
- First-ever Vote on-chain Supply Inflation rate to enable farmers to vote on-chain and automatic execution will be made based on the votes counted.
- YFV has a stable-coins pool which allows even small players to join the DeFi Yield Farming. The number of users will then be 100x or more compared to other DeFi Yield Farming Protocol.
- Referral and Burn On-chain to motivate the community who are giving a hand for bringing YFV to the public.
- Last but not least, the separated Elastic Supply Stable-coins vUSD and vETH are great add-on benefits for the farmers and the whole ecosystem later on along the road map.

### Smart contracts comparison with super-classes

[Diff checker: YFI and YFV](https://www.diffchecker.com/xmmWFRAg)

[Diff checker: YFIRewards and YFVRewards (Seed Pool)](https://www.diffchecker.com/PT4d1PSC)
 - Seed Pool supports 4 stables coin instead of a single y coin from the original code

[Diff checker: YFIRewards and YFV_Rewards_PoolXXX (Balancer/Uni Pool)](https://www.diffchecker.com/PWyndemv)
 - Removed rewardDistribution
 - notifyRewardAmount() can only call once by owner and reward amount cant be over TOTAL_REWARD
