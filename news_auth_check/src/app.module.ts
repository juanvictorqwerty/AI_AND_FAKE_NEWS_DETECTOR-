import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { envValidationSchema } from './config/env.validation';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { DatabaseModule } from './db/db.module';
import { ProfileModule } from './profile/profile.module';
import { FactCheckModule } from './fact-check/fact-check.module';

@Module({
    imports: [
        ConfigModule.forRoot({
            isGlobal: true,
            envFilePath: process.env.NODE_ENV === 'production' ? '.env.production' : '.env.development',
            validationSchema: envValidationSchema,
            validationOptions: {
                abortEarly: true,
            },
        }),
        DatabaseModule,
        AuthModule,
        UsersModule,
        ProfileModule,
        FactCheckModule,
    ],
    controllers: [AppController],
    providers: [AppService],
})
export class AppModule {}
