function clearConsole() {
  if (process.stdout.isTTY)
    process.stdout.write(process.platform === 'win32' ? '\x1B[2J\x1B[0f' : '\x1B[2J\x1B[3J\x1B[H');
}


export async function cancelPrompt(seconds: number) {
  for (let i = seconds; i >= 0; i--) {
    process.stdout.write(`\rStarting deployment in ${i} seconds...`);
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  process.stdout.write('\n');
  clearConsole();

  return true;
}
