
import { IsString, IsOptional, IsIn } from 'class-validator';
export class CreateDeviceDto {
  @IsString() projectId!: string;
  @IsString() name!: string;
  @IsOptional() @IsIn(['RELAY','SENSOR','CAMERA']) type?: 'RELAY'|'SENSOR'|'CAMERA';
}
