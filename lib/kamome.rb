# -*- coding: utf-8 -*-
require 'active_support/concern'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/kernel/concern'
require 'active_record'
require 'yaml'
require 'erb'

require_relative "kamome/version"
require_relative "kamome/config"
require_relative "kamome/errors"
require_relative "kamome/model"
require_relative "kamome/connection"
require_relative "kamome/ship"
require_relative "kamome/proxy"
require_relative "kamome/railtie" if defined?(Rails)

module Kamome
  extend self

  # 一時的に接続先を切り替える
  #
  #   Kamome.target = :blue                   # => :blue
  #   Kamome.anchor(:green) { Kamome.target } # => :green
  #   Kamome.target                           # => :blue
  #
  # 入れ子にできる
  #
  #   Kamome.anchor(:blue) do
  #     Kamome.target                 # => :blue
  #     Kamome.anchor(:green) do
  #       Kamome.target               # => :green
  #     end
  #     Kamome.target                 # => :blue
  #   end
  #
  def anchor(target_key, &block)
    stack.push(target)
    self.target = target_key
    if logger
      logger.tagged(target) { yield }
    else
      yield
    end
  ensure
    self.target = stack.pop
  end

  def target=(target_key)
    logger.info "Kamome: #{target.inspect} => #{target_key.inspect}" if logger
    Thread.current['kamome.target'] = target_key
  end

  def target
    Thread.current['kamome.target']
  end

  def stack
    Thread.current['kamome.stack'] ||= []
  end

  # 現在のtarget、もしくは指定したtarget_keyに対してtrasactionする
  def transaction(*args, &block)
    target_key = args.presence || target
    raise TargetNotFound, "transaction" unless target_key
    nested_transaction(transaction_target_models(target_key), &block)
  end

  # 水平分割用の全てのdatabaseでトランザクションを実行する
  def all_transaction(&block)
    nested_transaction(transaction_target_models(Kamome.config.shard_names), &block)
  end

  # マスターを含めて全てのdatabaseでトランザクションを実行する
  def full_transaction(&block)
    tagged("default transaction") do
      ActiveRecord::Base.transaction do
        all_transaction(&block)
      end
    end
  end

  def logger
    ActiveRecord::Base.logger
  end

  def tagged(tag)
    if logger
      logger.tagged(tag) { yield }
    else
      yield
    end
  end

  private

  def transaction_target_models(target_key)
    Array.wrap(target_key).collect{|v| Ship.unload(v).proxy_model }
  end

  def nested_transaction(models, &block)
    return block.call if models.empty?
    model = models.shift
    tagged("#{model.target_key} transaction") do
      model.transaction do
        nested_transaction(models, &block)
      end
    end
  end
end
