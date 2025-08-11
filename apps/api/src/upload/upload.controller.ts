
import { Controller, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import * as Minio from 'minio';
import * as multer from 'multer';

@Controller('upload')
export class UploadController {
  private client: Minio.Client;
  private bucket = process.env.MINIO_BUCKET || 'inspections';

  constructor() {
    this.client = new Minio.Client({
      endPoint: process.env.MINIO_ENDPOINT || 'localhost',
      port: Number(process.env.MINIO_PORT || 9000),
      useSSL: String(process.env.MINIO_USE_SSL||'false') === 'true',
      accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
      secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin',
    });
  }

  @Post()
  @UseInterceptors(FileInterceptor('file', { storage: multer.memoryStorage() }))
  async upload(@UploadedFile() file: Express.Multer.File) {
    if (!file) return { error: 'no_file' };
    const name = `${Date.now()}-${file.originalname}`;
    await this.ensureBucket();
    await this.client.putObject(this.bucket, name, file.buffer);
    const url = await this.client.presignedGetObject(this.bucket, name, 10 * 60);
    return { ok: true, key: name, url };
  }

  private async ensureBucket() {
    const exists = await this.client.bucketExists(this.bucket).catch(()=>false);
    if (!exists) await this.client.makeBucket(this.bucket, '');
  }
}
