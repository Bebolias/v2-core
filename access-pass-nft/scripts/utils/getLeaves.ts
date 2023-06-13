import { BigQuery } from '@google-cloud/bigquery';
import { LeafEntry } from './merkle-tree';

export async function getLeaves(projectId: string, tableName: string) : Promise<Array<LeafEntry>> {
    const bigQuery = getBigQuery(projectId);

    const tablePointer = `${projectId}.${tableName}`

    const sqlQuery = `SELECT * FROM \`${tablePointer}\``;

    const options = {
        query: sqlQuery,
    };

    const [rows] = await bigQuery.query(options);

    if (!rows || rows.length === 0) {
        return [];
    }

    const badges = new Map<string, number>();
    
    rows.forEach((e) => {
        const prevBalance = badges.get(e.walletAddress);
        if (prevBalance === undefined) {
            badges.set(e.walletAddress, 1) 
        } else {
            badges.set(e.walletAddress, prevBalance) 
        }
    })

    const result = new Array<LeafEntry>();
     Object.keys(badges).forEach((owner) => {
        result.push({
            owner: owner,
            badgesCount: badges.get(owner) ?? 0
        })
    });

    return result;
}

export const getBigQuery = (projectId: string): BigQuery => {
    const bigQuery = new BigQuery({
      projectId: projectId,
    });
  
    return bigQuery;
};