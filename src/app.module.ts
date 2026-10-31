import { Module } from '@nestjs/common';
import { HealthController } from './interface/rest/health.controller';

@Module({
  controllers: [HealthController],
})
export class AppModule {}
