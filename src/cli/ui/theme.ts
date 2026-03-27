import chalk from 'chalk';

export const c = {
  brand: chalk.hex('#FF6B35'),
  success: chalk.green,
  error: chalk.red,
  warning: chalk.yellow,
  info: chalk.cyan,
  dim: chalk.dim,
  bold: chalk.bold,
  white: chalk.white,
};

export const icons = {
  installed: chalk.green('✓'),
  skipped: chalk.dim('⟳'),
  failed: chalk.red('✗'),
  pending: chalk.dim('○'),
  running: chalk.cyan('◆'),
  retry: chalk.yellow('↻'),
  arrow: chalk.dim('→'),
  brew: '🍺',
  app: '📦',
  star: '⭐',
};
