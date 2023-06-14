import pinataSDK, { PinataPinOptions } from "@pinata/sdk";
import * as fs from "fs";

/**
 *
 * @param filePath: relative path to file
 * @param ipfsForlderName: desired IPFS folder name (can differ from local forlder)
 */
 export async function uploadFileIpfs(filePath: string, ipfsFileName: string) {
    const readableStreamForFile = fs.createReadStream(filePath);
    const pinata = new pinataSDK({ pinataJWTKey: process.env.PINATA_JWT });
    const options: PinataPinOptions = {
      pinataMetadata: {
        name: ipfsFileName,
      },
      pinataOptions: {
        cidVersion: 0,
      },
    };
    const resultPin = await pinata.pinFileToIPFS(readableStreamForFile, options);
    return resultPin.IpfsHash;
  }