import * as Joi from 'joi';

export const envValidationSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'production', 'test')
    .default('development'),
  PORT: Joi.number().default(4000),
  DATABASE_URL: Joi.string().required(),
  JWT_SECRET: Joi.string().required(),
  GOOGLE_FACT_CHECK_API_KEY: Joi.string().required(),
  OPENROUTER_API_KEY: Joi.string().required(),
  SERP_API_KEY: Joi.string().required(),
});
