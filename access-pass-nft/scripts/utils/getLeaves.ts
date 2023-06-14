import { BigQuery } from '@google-cloud/bigquery';
import { LeafEntry } from './merkle-tree';

const VOYAGE_TO_ADMIT_PASS : Record<number, number> = {
    0: 0,
    1: 3,
    2: 5,
    3: 8,
    4: 12
}

export async function getLeaves(projectId: string, tableName: string) : Promise<Array<LeafEntry>> {
    const bigQuery = getBigQuery(projectId);

    const tablePointer = `${projectId}.${tableName}`

    const sqlQuery = `SELECT DISTINCT walletAddress, voyageId FROM \`${tablePointer}\` WHERE chainId = 1`;

    const options = {
        query: sqlQuery,
    };

    const [rows] = await bigQuery.query(options);

    if (!rows || rows.length === 0) {
        return [];
    }

    const voyageCount = new Map<string, number>();
    
    rows.forEach((e) => {
        const prevBalance = voyageCount.get(e.walletAddress);
        if (prevBalance === undefined) {
            voyageCount.set(e.walletAddress, 1) 
        } else {
            voyageCount.set(e.walletAddress, prevBalance + 1) 
        }
    });

    const snapshot = new Array<LeafEntry>();
    voyageCount.forEach((count, owner) => {
        snapshot.push({
            owner: owner,
            badgesCount: VOYAGE_TO_ADMIT_PASS[count]
        })
    });

    console.log(snapshot)

    return snapshot;
}

export const getBigQuery = (projectId: string): BigQuery => {
    const bigQuery = new BigQuery({
      projectId: projectId,
    });
  
    return bigQuery;
};