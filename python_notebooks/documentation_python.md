- No duplicate Customer IDs were identified
- Valid age
- Valid Tenure
- Negative values on Monthly charge column found (120 customers, Between -1 and -10)
- Negative values are not correlated with refunds or with churn
- The decison is that negative Monthly charge values are invalid observations because a negative monthly customer charge is not economically meaningful in this dataset. The correct value cannot be reliably inferred from the available variables
- In the clean dataset the negative values are replaced with NaN
- Differences found on Total Charges column, these differences could be explained by customers upgrades or/and downgrades or others billing components
- Based on this explanation the column Total Charges remains unchanged/untreated
- No issues on churn-specifdic fields
- Forn churn analysis and ML the joined customers are not included
- Modeling dataset:
  Rows: 6,589
  Columns: 48
