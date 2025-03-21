import { NextResponse } from 'next/server';
import { createHash, createPrivateKey, createPublicKey } from 'crypto';
import jwt from 'jsonwebtoken';
import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';

function getRSAKey(): Buffer {
    return fs.readFileSync(path.join(process.cwd(), 'rsa_key.p8'));
}

function getDecryptedKey(passphrase: string): string {
    const keyPath = path.join(process.cwd(), 'rsa_key.p8');

    try {
        return execSync(`openssl pkcs8 -in ${keyPath} -passin pass:${passphrase} -nocrypt`, { encoding: 'utf8' });
    } catch (error) {
        try {
            return execSync(`openssl rsa -in ${keyPath} -passin pass:${passphrase}`, { encoding: 'utf8' });
        }
        catch (error) {
            throw new Error("Failed to decrypt private key: " + (error as Error).message);
        }
    }
}

export async function GET() {
    const SNOWFLAKE_RSA_PASSPHRASE = process.env.SNOWFLAKE_RSA_PASSPHRASE ?? '';
    const SNOWFLAKE_RSA_KEY = process.env.SNOWFLAKE_RSA_KEY ?? '';
    try {
        let rsaKey: string | Buffer;
        if (SNOWFLAKE_RSA_PASSPHRASE !== '' && SNOWFLAKE_RSA_KEY !== '') {
            rsaKey = getDecryptedKey(SNOWFLAKE_RSA_PASSPHRASE)
        } else {
            rsaKey = getRSAKey();
        }

        const privateKey = createPrivateKey(rsaKey);
        const publicKey = createPublicKey(privateKey);
        const publicKeyRaw = publicKey.export({ type: 'spki', format: 'der' });

        const sha256Hash = createHash('sha256').update(publicKeyRaw).digest('base64');
        const publicKeyFp = 'SHA256:' + sha256Hash;

        const account = process.env.SNOWFLAKE_ACCOUNT?.toUpperCase() ?? '';
        const user = process.env.SNOWFLAKE_USER?.toUpperCase() ?? '';
        const qualifiedUsername = `${account}.${user}`;

        const nowInSeconds = Math.floor(Date.now() / 1000);

        const oneHourInSeconds = 60 * 60;

        const payload = {
            iss: `${qualifiedUsername}.${publicKeyFp}`,
            sub: qualifiedUsername,
            iat: nowInSeconds,
            exp: nowInSeconds + oneHourInSeconds,
        };

        const token = jwt.sign(payload, rsaKey.toString(), { algorithm: 'RS256' });

        return NextResponse.json({
            token: {
                token,
                expiresAt: nowInSeconds + oneHourInSeconds - 120 // 2 minutes before actual expiration.
            }
        });
    } catch (error: unknown) {
        if (error instanceof Error) {
            return NextResponse.json({ error: error.message }, { status: 500 });
        }
        return NextResponse.json({ error: 'Unknown error' }, { status: 500 });
    }
}
