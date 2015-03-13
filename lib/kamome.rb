require 'active_support/concern'
# require 'active_support/core_ext/kernel/concern'
require 'active_record'
require 'yaml'

require_relative "kamome/version"
require_relative "kamome/config"
require_relative "kamome/connection"
require_relative "kamome/errors"
require_relative "kamome/model"
require_relative "kamome/proxy"
require_relative "kamome/proxy_station"
require_relative "kamome/railtie" if defined?(Rails)

module Kamome
  extend self

  # 強制的に接続先を切り替える
  #
  #  Profile.create!    # create blue db
  #  Kamome.anchor('green') do
  #    Profile.create!  # create green db
  #  end
  def anchor(target_key, &block)
    self.anchor_key = target_key
    yield
  ensure
    self.anchor_key = nil
  end

  def anchor_key=(target_key)
    Thread.current['kamome.anchor'] = target_key
  end

  def anchor_key
    Thread.current['kamome.anchor']
  end

  def target=(target_key)
    Thread.current[Kamome.config.thread_target_key] = target_key
  end

  def target
    Thread.current[Kamome.config.thread_target_key]
  end

  # 現在のtarget、もしくは指定したtarget_keyに対してtrasactionする
  def transaction(*args, &block)
    target_key = args.presence || target
    raise TargetNotFound if target_key.nil?
    nested_transaction(transaction_target_models(target_key), &block)
  end

  # 全てのdatabaseでトランザクションを実行する
  def full_transaction(&block)
    nested_transaction(transaction_target_models(Kamome.config.shard_names), &block)
  end

  private

  def transaction_target_models(target_key)
    Array.wrap(target_key).collect{|v| ProxyStation.checkout(v).proxy_model }
  end

  def nested_transaction(models, &block)
    return block.call if models.empty?
    model = models.shift
    model.transaction do
      nested_transaction(models, &block)
    end
  end
end
