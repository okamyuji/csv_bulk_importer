# typed: true
# frozen_string_literal: true

require "etc"

# Solid Queue / Puma / DB プールの並列度を「実際に使える CPU 数」から算出するヘルパ。
#
# 設計:
# - ECS Fargate のように cgroup CPU クォータが設定された環境では `Etc.nprocessors` が
#   ホストの CPU 数を返してしまうため、cgroup v2 の `/sys/fs/cgroup/cpu.max` を優先する。
# - ローカル開発環境（macOS など）では `Etc.nprocessors` をそのまま使う。
# - すべての値は ENV で上書き可能で、ENV が指定されたらそれを最優先する。
#
# ECS Fargate 標準タスクサイズに対する想定値:
#   0.5 vCPU → cpus=1 → workers=1, threads=2, pool=4
#   1   vCPU → cpus=1 → workers=1, threads=2, pool=4
#   2   vCPU → cpus=2 → workers=1, threads=4, pool=6
#   4   vCPU → cpus=4 → workers=3, threads=4, pool=20
#   8   vCPU → cpus=8 → workers=7, threads=8, pool=72 (要 RDS パラメータ調整)
module CpuConcurrency
  module_function

  CGROUP_V2_CPU_MAX = "/sys/fs/cgroup/cpu.max"
  CGROUP_V1_QUOTA   = "/sys/fs/cgroup/cpu/cpu.cfs_quota_us"
  CGROUP_V1_PERIOD  = "/sys/fs/cgroup/cpu/cpu.cfs_period_us"

  THREADS_MIN = 2
  THREADS_MAX = 8

  def cpus
    @cpus ||= cgroup_cpus || Etc.nprocessors
  end

  def cgroup_cpus
    if File.exist?(CGROUP_V2_CPU_MAX)
      quota, period = File.read(CGROUP_V2_CPU_MAX).split
      return nil if quota == "max"
      return [(quota.to_f / period.to_f).ceil, 1].max
    end
    if File.exist?(CGROUP_V1_QUOTA) && File.exist?(CGROUP_V1_PERIOD)
      quota = File.read(CGROUP_V1_QUOTA).to_i
      period = File.read(CGROUP_V1_PERIOD).to_i
      return nil if quota <= 0 || period <= 0
      return [(quota.to_f / period.to_f).ceil, 1].max
    end
    nil
  end

  # Solid Queue の同時実行プロセス数。Puma + Solid Queue dispatcher + queue/cache/cable
  # が全プロセスごとに DB コネクションを取るため、CPU 数の半分・最大 4 に抑える。
  # 12 cores → 4, 4 vCPU → 2, 1 vCPU → 1。ECS の Aurora 接続数(リーダー上限)とも整合する。
  PROCESSES_MAX = 4

  def job_processes
    ENV.fetch("JOB_CONCURRENCY") { [[(cpus / 2.0).ceil, PROCESSES_MAX].min, 1].max }.to_i
  end

  # 1 ワーカープロセスあたりのスレッド数。I/O 待ちが主なジョブ向けに最低 2、最大 8。
  def job_threads
    ENV.fetch("JOB_THREADS") { cpus.clamp(THREADS_MIN, THREADS_MAX) }.to_i
  end

  # Puma のスレッド数 (ENV RAILS_MAX_THREADS と整合)。
  def puma_threads
    ENV.fetch("RAILS_MAX_THREADS") { cpus.clamp(THREADS_MIN, THREADS_MAX) }.to_i
  end

  # 1 プロセスあたり必要な DB コネクション数。
  # Solid Queue ワーカープロセスは worker thread 数 + dispatcher 1 + poller 余裕 1 が必要。
  # Puma プロセスは puma_threads + 1 (ActionCable / 監視) を見ておく。
  def db_pool
    ENV.fetch("DB_POOL") { [job_threads + 2, puma_threads + 1].max }.to_i
  end

  def describe
    {
      cpus: cpus,
      cgroup_detected: !cgroup_cpus.nil?,
      job_processes: job_processes,
      job_threads: job_threads,
      puma_threads: puma_threads,
      db_pool: db_pool,
    }
  end
end
